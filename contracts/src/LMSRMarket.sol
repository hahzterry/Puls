// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { SD59x18, sd, unwrap, exp, ln } from "prb-math/SD59x18.sol";

/**
 * @title LMSRMarket
 * @notice Logarithmic Market Scoring Rule (LMSR) binary prediction market on Arc Testnet.
 *         Users buy YES or NO shares with USDC (6 decimals).
 *         Cost function: C = b * ln(exp(q1/b) + exp(q2/b))
 *
 * Arc Testnet:
 *   Chain ID : 5042002
 *   USDC     : 0x3600000000000000000000000000000000000000
 */
interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract LMSRMarket {
    // ── State ─────────────────────────────────────────────────────────────────

    IERC20 public immutable usdc;
    address public immutable owner;

    string  public slug;
    uint256 public deadline;
    bool    public resolved;
    bool    public outcome; // true = YES wins, false = NO wins

    // Liquid parameter `b` (USDC scaled to 6 decimals)
    uint256 public b;

    // Outstanding shares (6 decimals)
    uint256 public yesOutstanding;
    uint256 public noOutstanding;

    mapping(address => uint256) public yesShares;
    mapping(address => uint256) public noShares;
    mapping(address => bool)    public claimed;

    // ── Events ────────────────────────────────────────────────────────────────

    event Bought(address indexed user, bool side, uint256 amount, uint256 shares);
    event Sold(address indexed user, bool side, uint256 shares, uint256 usdcOut);
    event Resolved(bool outcome);
    event Claimed(address indexed user, uint256 payout);

    // ── Constructor ───────────────────────────────────────────────────────────

    bool public isFunded;

    constructor(
        address _usdc,
        string memory _slug,
        uint256 _deadline,
        uint256 _b // Liquidity parameter (e.g. 1000 USDC = 1_000_000_000)
    ) {
        require(_b > 0, "b required");
        usdc     = IERC20(_usdc);
        owner    = msg.sender;
        slug     = _slug;
        deadline = _deadline;
        b        = _b;
    }

    /// @notice The market creator must seed the maximum theoretical loss (subsidy)
    function fund() external {
        require(!isFunded, "Already funded");
        uint256 initialCost = getCostStable(0, 0);
        require(initialCost > 0, "Initial cost too small");
        usdc.transferFrom(msg.sender, address(this), initialCost);
        isFunded = true;
    }

    // ── Math (Log-Sum-Exp Trick) ───────────────────────────────────────────────

    /// @notice Stable implementation of C(q1, q2) = b * ln(exp(q1/b) + exp(q2/b))
    /// M = max(q1, q2)
    /// C = M + b * ln(exp((q1 - M)/b) + exp((q2 - M)/b))
    function getCostStable(uint256 q1, uint256 q2) public view returns (uint256) {
        SD59x18 b_sd = sd(int256(b * 1e12));
        SD59x18 q1_sd = sd(int256(q1 * 1e12));
        SD59x18 q2_sd = sd(int256(q2 * 1e12));

        SD59x18 max_q = q1_sd > q2_sd ? q1_sd : q2_sd;

        SD59x18 exp1 = exp((q1_sd.sub(max_q)).div(b_sd));
        SD59x18 exp2 = exp((q2_sd.sub(max_q)).div(b_sd));

        SD59x18 lnSum = ln(exp1.add(exp2));

        // cost = max_q + b * lnSum
        SD59x18 cost_sd = max_q.add(b_sd.mul(lnSum));

        int256 costInt = unwrap(cost_sd);
        return uint256(costInt) / 1e12;
    }

    /// @notice Returns YES shares obtained for spending `amount` USDC
    function calcBuyYesShares(uint256 amount) public view returns (uint256) {
        uint256 c0 = getCostStable(yesOutstanding, noOutstanding);
        uint256 c1 = c0 + amount;

        SD59x18 b_sd = sd(int256(b * 1e12));
        SD59x18 c1_sd = sd(int256(c1 * 1e12));
        SD59x18 q2_sd = sd(int256(noOutstanding * 1e12));
        
        SD59x18 expTerm = exp((q2_sd.sub(c1_sd)).div(b_sd)); 
        SD59x18 one = sd(1e18);
        SD59x18 inner = one.sub(expTerm);
        SD59x18 logInner = ln(inner);
        
        SD59x18 term = c1_sd.add(b_sd.mul(logInner));
        SD59x18 q1_sd = sd(int256(yesOutstanding * 1e12));
        SD59x18 delta_q_sd = term.sub(q1_sd);
        
        return uint256(unwrap(delta_q_sd)) / 1e12;
    }

    /// @notice Returns NO shares obtained for spending `amount` USDC
    function calcBuyNoShares(uint256 amount) public view returns (uint256) {
        uint256 c0 = getCostStable(yesOutstanding, noOutstanding);
        uint256 c1 = c0 + amount;

        SD59x18 b_sd = sd(int256(b * 1e12));
        SD59x18 c1_sd = sd(int256(c1 * 1e12));
        SD59x18 q1_sd = sd(int256(yesOutstanding * 1e12));
        
        SD59x18 expTerm = exp((q1_sd.sub(c1_sd)).div(b_sd)); 
        SD59x18 one = sd(1e18);
        SD59x18 inner = one.sub(expTerm);
        SD59x18 logInner = ln(inner);
        
        SD59x18 term = c1_sd.add(b_sd.mul(logInner));
        SD59x18 q2_sd = sd(int256(noOutstanding * 1e12));
        SD59x18 delta_q_sd = term.sub(q2_sd);
        
        return uint256(unwrap(delta_q_sd)) / 1e12;
    }

    function calcSellYesUsdc(uint256 shares) public view returns (uint256) {
        uint256 c0 = getCostStable(yesOutstanding, noOutstanding);
        uint256 c1 = getCostStable(yesOutstanding - shares, noOutstanding);
        return c0 - c1;
    }

    function calcSellNoUsdc(uint256 shares) public view returns (uint256) {
        uint256 c0 = getCostStable(yesOutstanding, noOutstanding);
        uint256 c1 = getCostStable(yesOutstanding, noOutstanding - shares);
        return c0 - c1;
    }

    // ── Trading ───────────────────────────────────────────────────────────────

    function buyYes(uint256 amount) external {
        require(isFunded, "Not funded");
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint256 boughtYes = calcBuyYesShares(amount);
        require(boughtYes > 0, "Slippage too high");

        yesOutstanding += boughtYes;
        yesShares[msg.sender] += boughtYes;

        emit Bought(msg.sender, true, amount, boughtYes);
    }

    function buyNo(uint256 amount) external {
        require(isFunded, "Not funded");
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint256 boughtNo = calcBuyNoShares(amount);
        require(boughtNo > 0, "Slippage too high");

        noOutstanding += boughtNo;
        noShares[msg.sender] += boughtNo;

        emit Bought(msg.sender, false, amount, boughtNo);
    }

    // ── Selling ───────────────────────────────────────────────────────────────

    function sellYes(uint256 shares) external {
        require(isFunded, "Not funded");
        require(!resolved, "Market resolved");
        require(yesShares[msg.sender] >= shares, "Insufficient shares");
        require(shares > 0, "Shares zero");

        uint256 usdcOut = calcSellYesUsdc(shares);
        require(usdcOut > 0, "Payout too small");

        yesShares[msg.sender] -= shares;
        yesOutstanding -= shares;

        usdc.transfer(msg.sender, usdcOut);

        emit Sold(msg.sender, true, shares, usdcOut);
    }

    function sellNo(uint256 shares) external {
        require(isFunded, "Not funded");
        require(!resolved, "Market resolved");
        require(noShares[msg.sender] >= shares, "Insufficient shares");
        require(shares > 0, "Shares zero");

        uint256 usdcOut = calcSellNoUsdc(shares);
        require(usdcOut > 0, "Payout too small");

        noShares[msg.sender] -= shares;
        noOutstanding -= shares;

        usdc.transfer(msg.sender, usdcOut);

        emit Sold(msg.sender, false, shares, usdcOut);
    }

    // ── Resolution ────────────────────────────────────────────────────────────

    function resolve(bool _outcome) external {
        require(msg.sender == owner, "Not owner");
        require(!resolved, "Already resolved");
        require(block.timestamp >= deadline, "Not yet");

        resolved = true;
        outcome  = _outcome;

        emit Resolved(_outcome);
    }

    function claim() external {
        require(resolved, "Not resolved");
        require(!claimed[msg.sender], "Already claimed");

        uint256 payout = outcome ? yesShares[msg.sender] : noShares[msg.sender];
        require(payout > 0, "No winning shares");

        claimed[msg.sender] = true;
        usdc.transfer(msg.sender, payout);

        emit Claimed(msg.sender, payout);
    }

    function ownerWithdraw() external {
        require(msg.sender == owner, "Not owner");
        require(resolved, "Not resolved");

        uint256 balance = usdc.balanceOf(address(this));
        usdc.transfer(msg.sender, balance);
    }

    // ── View ──────────────────────────────────────────────────────────────────

    function getMarketInfo() external view returns (
        string memory _slug,
        uint256 _deadline,
        bool _resolved,
        bool _outcome,
        uint256 _yesOutstanding,
        uint256 _noOutstanding
    ) {
        return (slug, deadline, resolved, outcome, yesOutstanding, noOutstanding);
    }

    function getUserPosition(address user) external view returns (
        uint256 _yesShares,
        uint256 _noShares,
        bool _claimed
    ) {
        return (yesShares[user], noShares[user], claimed[user]);
    }
}
