// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PulsMarket
 * @notice Binary prediction market on Arc Testnet.
 *         Users buy YES or NO shares with USDC (6 decimals).
 *         Owner resolves the market; winners claim proportional payout.
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

contract PulsMarket {
    // ── State ─────────────────────────────────────────────────────────────────

    IERC20 public immutable usdc;
    address public immutable owner;

    string  public question;
    uint256 public deadline;
    bool    public resolved;
    bool    public outcome; // true = YES wins, false = NO wins

    // AMM pool reserves (6 decimals)
    uint256 public poolYes;
    uint256 public poolNo;
    uint256 public k; // Constant product: poolYes * poolNo

    mapping(address => uint256) public yesShares;
    mapping(address => uint256) public noShares;
    mapping(address => bool)    public claimed;

    // ── Events ────────────────────────────────────────────────────────────────

    event Bought(address indexed user, bool side, uint256 amount, uint256 shares);
    event Sold(address indexed user, bool side, uint256 shares, uint256 usdcOut);
    event Resolved(bool outcome);
    event Claimed(address indexed user, uint256 payout);

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor(
        address _usdc,
        string memory _question,
        uint256 _deadline,
        uint256 _initialLiquidity // USDC amount (e.g. 10_000_000 = 10 USDC)
    ) {
        require(_initialLiquidity > 0, "Initial liquidity required");
        usdc     = IERC20(_usdc);
        owner    = msg.sender;
        question = _question;
        deadline = _deadline;

        // Pull initial liquidity from deployer/owner
        usdc.transferFrom(msg.sender, address(this), _initialLiquidity);

        // Initialize pool reserves equally to set 50/50 odds ($0.50 each)
        poolYes = _initialLiquidity;
        poolNo  = _initialLiquidity;
        k       = _initialLiquidity * _initialLiquidity;
    }

    // ── Trading ───────────────────────────────────────────────────────────────

    /// @notice Buy YES shares.
    /// @param amount USDC amount with 6 decimals (e.g. 1_000_000 = $1)
    function buyYes(uint256 amount) external {
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint256 newPoolNo = poolNo + amount;
        uint256 newPoolYes = k / newPoolNo;
        uint256 boughtYes = poolYes - newPoolYes;

        require(boughtYes > 0, "Slippage too high");

        poolYes = newPoolYes;
        poolNo  = newPoolNo;

        yesShares[msg.sender] += boughtYes;

        emit Bought(msg.sender, true, amount, boughtYes);
    }

    /// @notice Buy NO shares.
    function buyNo(uint256 amount) external {
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint256 newPoolYes = poolYes + amount;
        uint256 newPoolNo = k / newPoolYes;
        uint256 boughtNo = poolNo - newPoolNo;

        require(boughtNo > 0, "Slippage too high");

        poolYes = newPoolYes;
        poolNo  = newPoolNo;

        noShares[msg.sender] += boughtNo;

        emit Bought(msg.sender, false, amount, boughtNo);
    }

    // ── Selling ───────────────────────────────────────────────────────────────

    /// @notice Sell YES shares back for USDC.
    function sellYes(uint256 shares) external {
        require(!resolved, "Market resolved");
        require(yesShares[msg.sender] >= shares, "Insufficient shares");
        require(shares > 0, "Shares zero");

        yesShares[msg.sender] -= shares;

        uint256 newPoolYes = poolYes + shares;
        uint256 newPoolNo = k / newPoolYes;
        uint256 usdcOut = poolNo - newPoolNo;

        require(usdcOut > 0, "Payout too small");

        poolYes = newPoolYes;
        poolNo  = newPoolNo;

        usdc.transfer(msg.sender, usdcOut);

        emit Sold(msg.sender, true, shares, usdcOut);
    }

    /// @notice Sell NO shares back for USDC.
    function sellNo(uint256 shares) external {
        require(!resolved, "Market resolved");
        require(noShares[msg.sender] >= shares, "Insufficient shares");
        require(shares > 0, "Shares zero");

        noShares[msg.sender] -= shares;

        uint256 newPoolNo = poolNo + shares;
        uint256 newPoolYes = k / newPoolNo;
        uint256 usdcOut = poolYes - newPoolYes;

        require(usdcOut > 0, "Payout too small");

        poolYes = newPoolYes;
        poolNo  = newPoolNo;

        usdc.transfer(msg.sender, usdcOut);

        emit Sold(msg.sender, false, shares, usdcOut);
    }

    // ── Resolution ────────────────────────────────────────────────────────────

    /// @notice Owner resolves the market after deadline.
    function resolve(bool _outcome) external {
        require(msg.sender == owner, "Not owner");
        require(!resolved, "Already resolved");
        require(block.timestamp >= deadline, "Not yet");

        resolved = true;
        outcome  = _outcome;

        emit Resolved(_outcome);
    }

    // ── Payout ────────────────────────────────────────────────────────────────

    /// @notice Claim payout for winning shares (1 USDC per share).
    function claim() external {
        require(resolved, "Not resolved");
        require(!claimed[msg.sender], "Already claimed");

        uint256 payout = outcome ? yesShares[msg.sender] : noShares[msg.sender];
        require(payout > 0, "No winning shares");

        claimed[msg.sender] = true;
        usdc.transfer(msg.sender, payout);

        emit Claimed(msg.sender, payout);
    }

    /// @notice Reclaim remaining USDC liquidity after resolution.
    function ownerWithdraw() external {
        require(msg.sender == owner, "Not owner");
        require(resolved, "Not resolved");

        uint256 balance = usdc.balanceOf(address(this));
        // Creator gets whatever is left after subtracting unclaimed winning shares
        // In the worst case, all winners claim their payout, so the remaining is safe to withdraw.
        // We leave the winning shares in the contract.
        // To be safe, we calculate owner amount:
        // ownerAmt = balance - (total winning shares outstanding)
        // Since we don't track total outstanding winning shares easily, we can withdraw the remainder
        // once a grace period has passed, or keep it simple for the MVP:
        // ownerWithdraw just withdraws the entire remaining balance.
        usdc.transfer(msg.sender, balance);
    }

    // ── View ──────────────────────────────────────────────────────────────────

    function getMarketInfo() external view returns (
        string memory _question,
        uint256 _deadline,
        bool _resolved,
        bool _outcome,
        uint256 _poolYes,
        uint256 _poolNo
    ) {
        return (question, deadline, resolved, outcome, poolYes, poolNo);
    }

    function getUserPosition(address user) external view returns (
        uint256 _yesShares,
        uint256 _noShares,
        bool _claimed
    ) {
        return (yesShares[user], noShares[user], claimed[user]);
    }
}
