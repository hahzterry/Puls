// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { LMSRMarketFactory } from "../src/LMSRMarketFactory.sol";
import { LMSRMarket } from "../src/LMSRMarket.sol";
import { PulsMarket } from "../src/PulsMarket.sol";

contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        balanceOf[msg.sender] = 1_000_000 * 10**6; // 1 million USDC
        totalSupply = 1_000_000 * 10**6;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract MarketSecurityTest is Test {
    MockUSDC public usdc;
    LMSRMarketFactory public factory;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x111);
        user2 = address(0x222);

        usdc = new MockUSDC();
        factory = new LMSRMarketFactory(address(usdc));

        // Mint USDC to users
        usdc.mint(user1, 10_000 * 10**6);
        usdc.mint(user2, 10_000 * 10**6);
    }

    // ── LMSR Security Tests ───────────────────────────────────────────────────

    function testLmsrSafeWithdrawAndClaim() public {
        string memory slug = "lmsr-test";
        uint256 deadline = block.timestamp + 3600;
        uint256 b = 10 * 10**6; // 10 USDC

        // Seeding cost
        uint256 initialCost = 6931471;
        usdc.approve(address(factory), initialCost);

        // Deploy market
        address marketAddr = factory.createMarket(slug, deadline, b);
        LMSRMarket market = LMSRMarket(marketAddr);

        // User1 buys YES
        vm.startPrank(user1);
        usdc.approve(marketAddr, type(uint256).max);
        uint256 buyAmount = 10 * 10**6; // 10 USDC
        uint256 sharesBought = market.calcBuyYesShares(buyAmount);
        assertTrue(sharesBought > 0);
        market.buyYes(buyAmount);
        vm.stopPrank();

        // User2 buys NO
        vm.startPrank(user2);
        usdc.approve(marketAddr, type(uint256).max);
        market.buyNo(buyAmount);
        vm.stopPrank();

        // Move to deadline and resolve YES
        vm.warp(deadline);
        market.resolve(true);

        // Verify owner withdrawal is capped to leave enough USDC for winners
        uint256 outstandingWinners = market.yesOutstanding();
        uint256 contractBal = usdc.balanceOf(marketAddr);
        
        // Owner tries to withdraw
        uint256 ownerBalBefore = usdc.balanceOf(owner);
        market.ownerWithdraw();
        uint256 ownerBalAfter = usdc.balanceOf(owner);

        // Verify remaining contract balance is exactly equal to outstanding winner shares
        uint256 contractBalAfter = usdc.balanceOf(marketAddr);
        assertEq(contractBalAfter, outstandingWinners);
        assertEq(ownerBalAfter - ownerBalBefore, contractBal - outstandingWinners);

        // Verify user1 (winner) can successfully claim
        uint256 user1BalBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        market.claim();
        uint256 user1BalAfter = usdc.balanceOf(user1);

        assertEq(user1BalAfter - user1BalBefore, sharesBought);
        assertEq(usdc.balanceOf(marketAddr), outstandingWinners - sharesBought);
    }

    function testLmsrFundGating() public {
        LMSRMarket market = new LMSRMarket(address(usdc), "gating-test", block.timestamp + 3600, 10 * 10**6, owner);

        vm.startPrank(user1);
        vm.expectRevert("Not owner or factory");
        market.fund();
        vm.stopPrank();
    }

    function testLmsrLargeBuy() public {
        LMSRMarket market = new LMSRMarket(address(usdc), "math-test", block.timestamp + 3600, 10 * 10**6, owner);
        
        // Verify that a large buy works correctly and does not overflow
        uint256 shares = market.calcBuyYesShares(10_000 * 10**6);
        assertTrue(shares > 0);
    }

    // ── CPMM (PulsMarket) Security Tests ──────────────────────────────────────

    function testPulsSafeWithdrawAndClaim() public {
        uint256 initialLiquidity = 10 * 10**6; // 10 USDC
        
        // Pre-compute contract address and approve
        address predictedAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
        usdc.approve(predictedAddress, initialLiquidity);
        
        // Deploy PulsMarket
        PulsMarket market = new PulsMarket(
            address(usdc),
            "will btc hit 100k?",
            block.timestamp + 3600,
            initialLiquidity
        );
        address marketAddr = address(market);

        // User1 buys YES
        vm.startPrank(user1);
        usdc.approve(marketAddr, type(uint256).max);
        uint256 buyAmount = 15 * 10**6; // 15 USDC
        market.buyYes(buyAmount);
        uint256 yesShares = market.yesShares(user1);
        assertTrue(yesShares > 0);
        vm.stopPrank();

        // User2 buys NO
        vm.startPrank(user2);
        usdc.approve(marketAddr, type(uint256).max);
        market.buyNo(10 * 10**6);
        vm.stopPrank();

        // Warp to deadline and resolve YES
        vm.warp(block.timestamp + 3600);
        market.resolve(true);

        uint256 outstandingWinners = market.yesOutstanding();
        uint256 contractBal = usdc.balanceOf(marketAddr);

        // Owner withdraws
        uint256 ownerBalBefore = usdc.balanceOf(owner);
        market.ownerWithdraw();
        uint256 ownerBalAfter = usdc.balanceOf(owner);

        // Verify remaining contract balance is exactly equal to outstanding winner shares
        uint256 contractBalAfter = usdc.balanceOf(marketAddr);
        assertEq(contractBalAfter, outstandingWinners);
        assertEq(ownerBalAfter - ownerBalBefore, contractBal - outstandingWinners);

        // Verify user1 (winner) can successfully claim
        uint256 user1BalBefore = usdc.balanceOf(user1);
        vm.prank(user1);
        market.claim();
        uint256 user1BalAfter = usdc.balanceOf(user1);

        assertEq(user1BalAfter - user1BalBefore, yesShares);
    }

    function testPulsMinLiquidity() public {
        vm.expectRevert("Initial liquidity must be >= 1 USDC");
        new PulsMarket(
            address(usdc),
            "will btc hit 100k?",
            block.timestamp + 3600,
            999_999 // < 1 USDC
        );
    }

    // ── Ownable2Step Verification ─────────────────────────────────────────────

    function testOwnable2Step() public {
        // Test Factory Ownable2Step
        factory.transferOwnership(user1);
        assertEq(factory.owner(), owner);
        assertEq(factory.pendingOwner(), user1);

        // Non-pending owner tries to accept
        vm.prank(user2);
        vm.expectRevert("Not pending owner");
        factory.acceptOwnership();

        // Pending owner accepts
        vm.prank(user1);
        factory.acceptOwnership();
        assertEq(factory.owner(), user1);
        assertEq(factory.pendingOwner(), address(0));
    }
}
