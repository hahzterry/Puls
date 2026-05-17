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

    uint256 public totalYes;  // total USDC in YES pool (6 decimals)
    uint256 public totalNo;   // total USDC in NO pool  (6 decimals)

    mapping(address => uint256) public yesShares;
    mapping(address => uint256) public noShares;
    mapping(address => bool)    public claimed;

    // ── Events ────────────────────────────────────────────────────────────────

    event Bought(address indexed user, bool side, uint256 amount);
    event Resolved(bool outcome);
    event Claimed(address indexed user, uint256 payout);

    // ── Constructor ───────────────────────────────────────────────────────────

    constructor(
        address _usdc,
        string memory _question,
        uint256 _deadline
    ) {
        usdc     = IERC20(_usdc);
        owner    = msg.sender;
        question = _question;
        deadline = _deadline;
    }

    // ── Trading ───────────────────────────────────────────────────────────────

    /// @notice Buy YES shares. Caller must approve this contract first.
    /// @param amount USDC amount with 6 decimals (e.g. 1_000_000 = $1)
    function buyYes(uint256 amount) external {
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);
        yesShares[msg.sender] += amount;
        totalYes += amount;

        emit Bought(msg.sender, true, amount);
    }

    /// @notice Buy NO shares. Caller must approve this contract first.
    function buyNo(uint256 amount) external {
        require(!resolved, "Market resolved");
        require(block.timestamp < deadline, "Market closed");
        require(amount > 0, "Amount zero");

        usdc.transferFrom(msg.sender, address(this), amount);
        noShares[msg.sender] += amount;
        totalNo += amount;

        emit Bought(msg.sender, false, amount);
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

    /// @notice Winners claim their proportional share of the total pool.
    function claim() external {
        require(resolved, "Not resolved");
        require(!claimed[msg.sender], "Already claimed");

        uint256 userShares = outcome ? yesShares[msg.sender] : noShares[msg.sender];
        require(userShares > 0, "No winning shares");

        uint256 winPool  = outcome ? totalYes : totalNo;
        uint256 losePool = outcome ? totalNo  : totalYes;
        uint256 total    = winPool + losePool;

        // Payout = user's share of win pool + proportional share of losing pool
        uint256 payout = (userShares * total) / winPool;

        claimed[msg.sender] = true;
        usdc.transfer(msg.sender, payout);

        emit Claimed(msg.sender, payout);
    }

    // ── View ──────────────────────────────────────────────────────────────────

    function getMarketInfo() external view returns (
        string memory _question,
        uint256 _deadline,
        bool _resolved,
        bool _outcome,
        uint256 _totalYes,
        uint256 _totalNo
    ) {
        return (question, deadline, resolved, outcome, totalYes, totalNo);
    }

    function getUserPosition(address user) external view returns (
        uint256 _yesShares,
        uint256 _noShares,
        bool _claimed
    ) {
        return (yesShares[user], noShares[user], claimed[user]);
    }
}
