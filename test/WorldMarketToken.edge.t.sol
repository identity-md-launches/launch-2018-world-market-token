// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {WorldMarketToken} from "src/WorldMarketToken.sol";

/// @notice Boundary values and approval lifecycles complement the existing issuance tests.
/// forge-config: default.fuzz.runs = 1000
contract WorldMarketTokenEdgeTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 1e18;
    WorldMarketToken private token;
    address private alice;
    address private bob;
    address private spender;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        token = new WorldMarketToken();
        alice = makeAddr("edge alice");
        bob = makeAddr("edge bob");
        spender = makeAddr("edge spender");
    }

    function test_smallestUnitCanBeSpentExactlyOnce() public {
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 1));
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 1);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.allowance(alice, spender), 0);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        vm.prank(bob);
        assertTrue(token.transfer(address(this), 1));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumMinusOneAllowanceIsFinite() public {
        uint256 approved = type(uint256).max - 1;
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), approved - 1);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY - 1));
        assertEq(token.allowance(address(this), spender), approved - SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteAllowanceCannotBypassBalanceCheck() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        vm.prank(spender);
        token.transferFrom(address(this), alice, type(uint256).max);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteAllowanceCanBeReducedAndRevoked() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 2);
        assertTrue(token.approve(spender, 2));
        assertEq(token.allowance(address(this), spender), 2);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertEq(token.allowance(address(this), spender), 1);

        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 0);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
    }

    function test_approvalBeforeFundingSurvivesFailureAndRefill() public {
        vm.prank(alice);
        assertTrue(token.approve(spender, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        assertEq(token.allowance(alice, spender), 2);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);

        assertTrue(token.transfer(alice, 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));
        assertEq(token.allowance(alice, spender), 1);
        assertEq(token.balanceOf(alice), 0);
        assertTrue(token.transfer(alice, 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 2);
        assertEq(token.balanceOf(address(this)), SUPPLY - 2);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferFromByOwnerUsesItsOwnApproval() public {
        assertTrue(token.transfer(alice, 2));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        vm.prank(alice);
        assertTrue(token.approve(alice, 2));
        vm.prank(alice);
        assertTrue(token.transferFrom(alice, alice, 1));
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.allowance(alice, alice), 1);
        vm.prank(alice);
        assertTrue(token.transferFrom(alice, bob, 1));
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.allowance(alice, alice), 0);
    }

    function test_approvalDoesNotFollowTokensToTheirNewOwner() public {
        assertTrue(token.approve(spender, type(uint256).max));
        assertTrue(token.transfer(alice, SUPPLY));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.balanceOf(bob), 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, SUPPLY));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), SUPPLY);
    }

    function test_zeroTransfersPreserveExistingBalancesAndAllowance() public {
        assertTrue(token.transfer(alice, 7));
        assertTrue(token.transfer(bob, 3));
        vm.prank(alice);
        assertTrue(token.approve(spender, type(uint256).max - 1));
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.balanceOf(alice), 7);
        assertEq(token.balanceOf(bob), 3);
        assertEq(token.allowance(alice, spender), type(uint256).max - 1);
        assertEq(token.balanceOf(address(this)), SUPPLY - 10);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroSpenderRejectedForZeroAndMaximumApproval() public {
        assertTrue(token.approve(spender, 5));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), type(uint256).max);
        assertEq(token.allowance(address(this), address(0)), 0);
        assertEq(token.allowance(address(this), spender), 5);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    function test_zeroRecipientRejectedWithInfiniteAllowance() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 1);
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_tokenContractCanReceiveTokensWithoutBurningThem() public {
        assertTrue(token.transfer(address(token), 1));
        assertTrue(token.approve(spender, SUPPLY - 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), address(token), SUPPLY - 1));
        assertEq(token.balanceOf(address(token)), SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_stateChangingFunctionsRejectEtherAtomically() public {
        vm.deal(address(this), 1 ether);
        assertTrue(token.approve(address(this), 7));
        assertTrue(token.approve(spender, 5));
        bytes[3] memory calls = [
            abi.encodeCall(token.transfer, (alice, 1)),
            abi.encodeCall(token.approve, (spender, 9)),
            abi.encodeCall(token.transferFrom, (address(this), alice, 1))
        ];
        for (uint256 i; i < calls.length; ++i) {
            (bool success,) = address(token).call{value: 1}(calls[i]);
            assertFalse(success, "nonpayable operation accepted ETH");
            assertEq(token.balanceOf(address(this)), SUPPLY);
            assertEq(token.balanceOf(alice), 0);
            assertEq(token.allowance(address(this), address(this)), 7);
            assertEq(token.allowance(address(this), spender), 5);
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(address(token).balance, 0);
            assertEq(address(this).balance, 1 ether);
        }
    }

    function testFuzz_insufficientAllowanceIsAtomic(uint256 balance, uint256 amount, uint256 approved) public {
        balance = bound(balance, 1, SUPPLY);
        amount = bound(amount, 1, balance);
        approved = bound(approved, 0, amount - 1);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, approved, amount)
        );
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_insufficientBalanceRestoresArbitraryAllowance(uint256 balance, uint256 amount, uint256 approved)
        public
    {
        balance = bound(balance, 0, SUPPLY);
        amount = bound(amount, balance + 1, type(uint256).max);
        approved = bound(approved, amount, type(uint256).max);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, approved));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(spender);
        token.transferFrom(alice, bob, amount);
        assertEq(token.allowance(alice, spender), approved);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_revocationAfterSpendingSurvivesNewFunding(uint256 balance, uint256 spent, bool infinite) public {
        balance = bound(balance, 2, SUPPLY - 1);
        spent = bound(spent, 1, balance - 1);
        assertTrue(token.transfer(alice, balance));
        vm.prank(alice);
        assertTrue(token.approve(spender, infinite ? type(uint256).max : balance));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, spent));
        assertEq(token.allowance(alice, spender), infinite ? type(uint256).max : balance - spent);
        vm.prank(alice);
        assertTrue(token.approve(spender, 0));
        assertTrue(token.transfer(alice, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.balanceOf(alice), balance - spent + 1);
        assertEq(token.balanceOf(bob), spent);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferRoundTripRestoresBothBalances(uint256 aliceBalance, uint256 amount) public {
        aliceBalance = bound(aliceBalance, 0, SUPPLY);
        amount = bound(amount, 0, aliceBalance);
        uint256 bobBalance = SUPPLY - aliceBalance;
        assertTrue(token.transfer(alice, aliceBalance));
        assertTrue(token.transfer(bob, bobBalance));
        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));
        assertEq(token.balanceOf(alice), aliceBalance - amount);
        assertEq(token.balanceOf(bob), bobBalance + amount);
        vm.prank(bob);
        assertTrue(token.transfer(alice, amount));
        assertEq(token.balanceOf(alice), aliceBalance);
        assertEq(token.balanceOf(bob), bobBalance);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_twoSpendersCannotSpendTheSameBalanceTwice(uint256 balance, uint256 firstSpend) public {
        balance = bound(balance, 1, SUPPLY);
        firstSpend = bound(firstSpend, 1, balance);
        assertTrue(token.transfer(alice, balance));
        vm.startPrank(alice);
        assertTrue(token.approve(spender, balance));
        assertTrue(token.approve(bob, balance));
        vm.stopPrank();
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, spender, firstSpend));
        uint256 remaining = balance - firstSpend;

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, remaining, balance)
        );
        vm.prank(bob);
        token.transferFrom(alice, bob, balance);
        assertEq(token.allowance(alice, bob), balance);
        assertEq(token.allowance(alice, spender), remaining);
        assertEq(token.balanceOf(alice), remaining);
        assertEq(token.balanceOf(bob), 0);

        vm.prank(bob);
        assertTrue(token.transferFrom(alice, bob, remaining));
        assertEq(token.allowance(alice, bob), firstSpend);
        assertEq(token.allowance(alice, spender), remaining);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(spender), firstSpend);
        assertEq(token.balanceOf(bob), remaining);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }
}
