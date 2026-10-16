// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {WorldMarketToken} from "../src/WorldMarketToken.sol";

/// @dev Test-only model. All token holders in this campaign are in actors.
contract WorldTokenHandler is Test {
    WorldMarketToken public immutable token;
    address[4] public actors;
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(WorldMarketToken token_) {
        token = token_;
        actors = [makeAddr("actor0"), makeAddr("actor1"), makeAddr("actor2"), makeAddr("actor3")];
        expectedBalance[actors[0]] = 1_000_000_000 * 1e18;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        amount = bound(amount, 0, expectedBalance[from]);
        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        expectedBalance[from] -= amount;
        expectedBalance[to] += amount;
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount, bool infinite) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        amount = infinite ? type(uint256).max : amount;
        vm.prank(owner);
        assertTrue(token.approve(spender, amount));
        expectedAllowance[owner][spender] = amount;
    }

    function spend(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 approved = expectedAllowance[owner][spender];
        uint256 balance = expectedBalance[owner];
        amount = bound(amount, 0, approved < balance ? approved : balance);
        vm.prank(spender);
        assertTrue(token.transferFrom(owner, to, amount));
        expectedBalance[owner] -= amount;
        expectedBalance[to] += amount;
        if (approved != type(uint256).max) {
            expectedAllowance[owner][spender] -= amount;
        }
    }

    /// @dev Keep a raw amount path beside spend's successful bounded path. Failed calls must
    /// leave the entire balance/allowance model unchanged, including unrelated actors.
    function spendUnbounded(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 approved = expectedAllowance[owner][spender];
        uint256 balance = expectedBalance[owner];

        if (amount > approved) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, amount)
            );
            vm.prank(spender);
            token.transferFrom(owner, to, amount);
        } else if (amount > balance) {
            vm.expectRevert(
                abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, owner, balance, amount)
            );
            vm.prank(spender);
            token.transferFrom(owner, to, amount);
        } else {
            vm.prank(spender);
            assertTrue(token.transferFrom(owner, to, amount));
            expectedBalance[owner] -= amount;
            expectedBalance[to] += amount;
            if (approved != type(uint256).max) {
                expectedAllowance[owner][spender] -= amount;
            }
        }
    }

    function revokeAndAttemptSpend(uint256 ownerSeed, uint256 spenderSeed, uint256 toSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        address to = actors[toSeed % actors.length];
        vm.prank(owner);
        assertTrue(token.approve(spender, 0));
        expectedAllowance[owner][spender] = 0;

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(owner, to, 1);
    }

    function attemptZeroRecipient(uint256 ownerSeed, uint256 spenderSeed, uint256 amount, bool delegated) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 maximum = expectedBalance[owner];
        uint256 approved = expectedAllowance[owner][spender];
        if (delegated && approved < maximum) maximum = approved;
        amount = bound(amount, 0, maximum);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(delegated ? spender : owner);
        if (delegated) token.transferFrom(owner, address(0), amount);
        else token.transfer(address(0), amount);
    }

    function attemptZeroSpender(uint256 ownerSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(owner);
        token.approve(address(0), amount);
    }

    /// @dev A full-balance round trip tests that holders remain able to move every last unit
    /// after arbitrary approval changes and failures. Check both legs so errors cannot cancel.
    function fullBalanceRoundTrip(uint256 fromSeed, uint256 toSeed) external {
        uint256 fromIndex = fromSeed % actors.length;
        address from = actors[fromIndex];
        address to = actors[(fromIndex + 1 + toSeed % (actors.length - 1)) % actors.length];
        uint256 amount = expectedBalance[from];
        uint256 toBalance = expectedBalance[to];

        vm.prank(from);
        assertTrue(token.transfer(to, amount));
        assertEq(token.balanceOf(from), 0);
        assertEq(token.balanceOf(to), toBalance + amount);
        assertEq(token.totalSupply(), 1_000_000_000 * 1e18);

        vm.prank(to);
        assertTrue(token.transfer(from, amount));
        assertEq(token.balanceOf(from), amount);
        assertEq(token.balanceOf(to), toBalance);
        // The expected ledger is unchanged by this round trip.
    }

    function attemptOverdraw(uint256 fromSeed, uint256 toSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 balance = expectedBalance[from];
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, from, balance, balance + 1)
        );
        vm.prank(from);
        token.transfer(to, balance + 1);
    }
}

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 128
/// forge-config: default.invariant.fail-on-revert = true
contract WorldMarketTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 1e18;
    WorldMarketToken private token;
    WorldTokenHandler private handler;

    function setUp() public {
        token = new WorldMarketToken();
        handler = new WorldTokenHandler(token);
        token.transfer(handler.actors(0), SUPPLY);

        bytes4[] memory selectors = new bytes4[](9);
        selectors[0] = WorldTokenHandler.transfer.selector;
        selectors[1] = WorldTokenHandler.approve.selector;
        selectors[2] = WorldTokenHandler.spend.selector;
        selectors[3] = WorldTokenHandler.attemptOverdraw.selector;
        selectors[4] = WorldTokenHandler.spendUnbounded.selector;
        selectors[5] = WorldTokenHandler.revokeAndAttemptSpend.selector;
        selectors[6] = WorldTokenHandler.attemptZeroRecipient.selector;
        selectors[7] = WorldTokenHandler.attemptZeroSpender.selector;
        selectors[8] = WorldTokenHandler.fullBalanceRoundTrip.selector;
        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_supplyAndBalancesMatchModel() public view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            address actor = handler.actors(i);
            uint256 balance = token.balanceOf(actor);
            assertEq(balance, handler.expectedBalance(actor));
            sum += balance;
        }
        assertEq(sum, SUPPLY);
    }

    function invariant_allowancesMatchModel() public view {
        for (uint256 i; i < 4; ++i) {
            assertEq(token.allowance(handler.actors(i), address(0)), 0);
            assertEq(token.allowance(address(0), handler.actors(i)), 0);
            for (uint256 j; j < 4; ++j) {
                address owner = handler.actors(i);
                address spender = handler.actors(j);
                assertEq(token.allowance(owner, spender), handler.expectedAllowance(owner, spender));
            }
        }
    }

    function invariant_metadataRemainsUnchanged() public view {
        assertEq(token.name(), "World Market Token");
        assertEq(token.symbol(), "WORLD");
        assertEq(token.decimals(), 18);
        assertEq(token.INITIAL_SUPPLY(), SUPPLY);
    }

    /// @dev Exercise every actor's ability to transfer its entire balance after each campaign.
    function afterInvariant() public {
        for (uint256 i; i < 4; ++i) {
            handler.fullBalanceRoundTrip(i, 0);
        }
        invariant_supplyAndBalancesMatchModel();
        invariant_allowancesMatchModel();
    }
}
