// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {WorldMarketToken} from "../src/WorldMarketToken.sol";
import {TokenFactoryProbe} from "./helpers/TokenFactoryProbe.sol";

contract WorldMarketTokenTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 1e18;

    WorldMarketToken private token;
    address private alice;
    address private bob;
    address private spender;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        spender = makeAddr("spender");
        token = new WorldMarketToken();
    }

    function test_metadataAndInitialSupply() public view {
        assertEq(token.name(), "World Market Token");
        assertEq(token.symbol(), "WORLD");
        assertEq(token.decimals(), 18);
        assertEq(token.INITIAL_SUPPLY(), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.allowance(address(this), spender), 0);
    }

    function test_constructorEmitsExactlyOneMint() public {
        vm.recordLogs();
        WorldMarketToken fresh = new WorldMarketToken();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1);
        assertEq(logs[0].emitter, address(fresh));
        assertEq(logs[0].topics.length, 3);
        assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
        assertEq(logs[0].topics[1], bytes32(0));
        assertEq(logs[0].topics[2], bytes32(uint256(uint160(address(this)))));
        assertEq(abi.decode(logs[0].data, (uint256)), SUPPLY);
    }

    function test_directDeploymentMintsToCaller() public {
        vm.prank(alice);
        WorldMarketToken fresh = new WorldMarketToken();
        assertEq(fresh.balanceOf(alice), SUPPLY);
        assertEq(fresh.balanceOf(address(this)), 0);
    }

    function test_factoryDeploymentMintsAllToFactory() public {
        TokenFactoryProbe factory = new TokenFactoryProbe();
        vm.prank(alice);
        WorldMarketToken fresh = factory.deploy(keccak256("WORLD launch"));
        assertEq(fresh.totalSupply(), SUPPLY);
        assertEq(fresh.balanceOf(address(factory)), SUPPLY);
        assertEq(fresh.balanceOf(alice), 0);
        assertEq(fresh.balanceOf(address(this)), 0);
        assertEq(fresh.balanceOf(address(fresh)), 0);
    }

    function test_transferMovesExactAmountAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), alice, 123e18);
        assertTrue(token.transfer(alice, 123e18));
        assertEq(token.balanceOf(address(this)), SUPPLY - 123e18);
        assertEq(token.balanceOf(alice), 123e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferEntireSupply() public {
        assertTrue(token.transfer(alice, SUPPLY));
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        vm.prank(alice);
        assertTrue(token.transfer(bob, SUPPLY));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), SUPPLY);
    }

    function test_zeroTransferFromEmptyAccountEmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(alice, bob, 0);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 0));
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_selfTransferPreservesBalance() public {
        assertTrue(token.transfer(address(this), SUPPLY));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferToZeroRevertsEvenForZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 1);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_transferOverBalanceReverts() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, SUPPLY + 1)
        );
        token.transfer(alice, SUPPLY + 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_transferMaximumIntegerRevertsWithoutOverflow() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, type(uint256).max
            )
        );
        token.transfer(alice, type(uint256).max);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_selfTransferStillRequiresBalance() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, 1));
        vm.prank(alice);
        token.transfer(alice, 1);
    }

    function test_approveEmitsEventWithoutMovingTokens() public {
        vm.expectEmit(true, true, false, true, address(token));
        emit Approval(address(this), spender, 200e18);
        assertTrue(token.approve(spender, 200e18));
        assertEq(token.allowance(address(this), spender), 200e18);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(spender), 0);
    }

    function test_approvalCanBeReplacedAndRevoked() public {
        token.approve(spender, 200e18);
        token.approve(spender, 50e18);
        assertEq(token.allowance(address(this), spender), 50e18);
        token.approve(spender, 0);
        assertEq(token.allowance(address(this), spender), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 1);
    }

    function test_approveZeroSpenderReverts() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 1);
    }

    function test_approvalIsSpecificToOwnerAndSpender() public {
        token.approve(spender, 50e18);
        vm.prank(alice);
        token.approve(spender, 25e18);
        assertEq(token.allowance(address(this), spender), 50e18);
        assertEq(token.allowance(alice, spender), 25e18);
        assertEq(token.allowance(address(this), bob), 0);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, bob, 0, 1));
        vm.prank(bob);
        token.transferFrom(address(this), alice, 1);
    }

    function test_transferFromEmitsTransferAndSpendsAllowance() public {
        token.approve(spender, 100e18);
        vm.expectEmit(true, true, false, true, address(token));
        emit Transfer(address(this), alice, 40e18);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 40e18));
        assertEq(token.balanceOf(alice), 40e18);
        assertEq(token.balanceOf(address(this)), SUPPLY - 40e18);
        assertEq(token.allowance(address(this), spender), 60e18);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, 60e18));
        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(bob), 60e18);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteAllowanceIsNotDecreased() public {
        token.approve(spender, type(uint256).max);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));
        assertEq(token.allowance(address(this), spender), type(uint256).max);
        assertEq(token.balanceOf(alice), SUPPLY);
    }

    function test_transferFromSelfSpendsAllowanceWithoutMovingBalance() public {
        token.approve(spender, 100e18);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), address(this), 40e18));
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.allowance(address(this), spender), 60e18);
    }

    function test_zeroTransferFromNeedsNoAllowance() public {
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 0));
        assertEq(token.allowance(alice, spender), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_transferFromInsufficientAllowanceRevertsAtomically() public {
        token.approve(spender, 10);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 10, 11));
        vm.prank(spender);
        token.transferFrom(address(this), alice, 11);
        assertEq(token.allowance(address(this), spender), 10);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_transferFromInsufficientBalanceRestoresAllowance() public {
        token.approve(spender, SUPPLY + 1);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), SUPPLY, SUPPLY + 1)
        );
        vm.prank(spender);
        token.transferFrom(address(this), alice, SUPPLY + 1);
        assertEq(token.allowance(address(this), spender), SUPPLY + 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_transferFromToZeroRestoresAllowance() public {
        token.approve(spender, 50);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 50);
        assertEq(token.allowance(address(this), spender), 50);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroAddressCannotBeTransferFromSource() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(0), alice, 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_deployerCannotSpendHolderTokensWithoutApproval() public {
        token.transfer(alice, 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 100e18)
        );
        token.transferFrom(alice, address(this), 100e18);
        assertEq(token.balanceOf(alice), 100e18);
        vm.prank(alice);
        assertTrue(token.transfer(bob, 100e18));
    }

    function test_launchDistributionAndClaimsArriveWhole() public {
        TokenFactoryProbe factory = new TokenFactoryProbe();
        WorldMarketToken fresh = factory.deploy(keccak256("distribution"));
        address distributor = makeAddr("distributor");
        address pool = makeAddr("pool manager");
        address remainder = makeAddr("remainder recipient");
        vm.startPrank(address(factory));
        assertTrue(fresh.transfer(distributor, SUPPLY / 10));
        assertTrue(fresh.transfer(pool, SUPPLY * 8 / 10));
        assertTrue(fresh.transfer(remainder, SUPPLY / 10));
        vm.stopPrank();
        assertEq(fresh.balanceOf(address(factory)), 0);
        assertEq(fresh.balanceOf(distributor), SUPPLY / 10);
        assertEq(fresh.balanceOf(pool), SUPPLY * 8 / 10);
        assertEq(fresh.balanceOf(remainder), SUPPLY / 10);
        vm.prank(distributor);
        assertTrue(fresh.transfer(alice, SUPPLY / 10));
        assertEq(fresh.balanceOf(distributor), 0);
        assertEq(fresh.balanceOf(alice), SUPPLY / 10);
        vm.prank(pool);
        assertTrue(fresh.transfer(bob, 12e18));
        vm.prank(bob);
        assertTrue(fresh.transfer(pool, 12e18));
        assertEq(fresh.balanceOf(pool), SUPPLY * 8 / 10);
        assertEq(fresh.balanceOf(bob), 0);
        assertEq(fresh.totalSupply(), SUPPLY);
    }

    function test_noMintBurnOrAdministrativeEntryPoints() public {
        token.transfer(alice, 100e18);
        bytes[] memory calls = new bytes[](15);
        calls[0] = abi.encodeWithSignature("mint(address,uint256)", bob, 1e18);
        calls[1] = abi.encodeWithSignature("mint(uint256)", 1e18);
        calls[2] = abi.encodeWithSignature("mint()");
        calls[3] = abi.encodeWithSignature("burn(uint256)", 1e18);
        calls[4] = abi.encodeWithSignature("burnFrom(address,uint256)", alice, 1e18);
        calls[5] = abi.encodeWithSignature("pause()");
        calls[6] = abi.encodeWithSignature("blacklist(address)", alice);
        calls[7] = abi.encodeWithSignature("freeze(address)", alice);
        calls[8] = abi.encodeWithSignature("seize(address)", alice);
        calls[9] = abi.encodeWithSignature("setMinter(address)", bob);
        calls[10] = abi.encodeWithSignature("initialize(address)", bob);
        calls[11] = abi.encodeWithSignature("transferOwnership(address)", bob);
        calls[12] = abi.encodeWithSignature("upgradeTo(address)", bob);
        calls[13] = abi.encodeWithSignature("setTransfersEnabled(bool)", false);
        calls[14] = abi.encodeWithSignature("owner()");
        for (uint256 i; i < calls.length; ++i) {
            (bool deployerSucceeded,) = address(token).call(calls[i]);
            assertFalse(deployerSucceeded, "deployer reached an unsupported function");
            vm.prank(bob);
            (bool strangerSucceeded,) = address(token).call(calls[i]);
            assertFalse(strangerSucceeded, "stranger reached an unsupported function");
            assertEq(token.totalSupply(), SUPPLY);
            assertEq(token.balanceOf(alice), 100e18);
            assertEq(token.balanceOf(bob), 0);
        }
        vm.prank(alice);
        assertTrue(token.transfer(bob, 100e18));
    }

    function test_plainEtherTransferIsRejected() public {
        vm.deal(address(this), 1 ether);
        (bool success,) = address(token).call{value: 1 ether}("");
        assertFalse(success);
        assertEq(address(token).balance, 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferConservesSupply(address recipient, uint256 amount) public {
        vm.assume(recipient != address(0) && recipient != address(this));
        amount = bound(amount, 0, SUPPLY);
        assertTrue(token.transfer(recipient, amount));
        assertEq(token.balanceOf(recipient), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.balanceOf(recipient) + token.balanceOf(address(this)), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_transferFromTracksAllowance(uint256 approved, uint256 amount) public {
        amount = bound(amount, 0, SUPPLY);
        approved = bound(approved, amount, type(uint256).max);
        token.approve(spender, approved);
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, amount));
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.allowance(address(this), spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_overBalanceTransferIsAtomic(uint256 balance, uint256 excess) public {
        balance = bound(balance, 0, SUPPLY);
        excess = bound(excess, 1, type(uint256).max - balance);
        token.transfer(alice, balance);
        uint256 amount = balance + excess;
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, balance, amount));
        vm.prank(alice);
        token.transfer(bob, amount);
        assertEq(token.balanceOf(alice), balance);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - balance);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_unapprovedSpenderCannotMoveTokens(address caller, uint256 amount) public {
        vm.assume(caller != address(0));
        amount = bound(amount, 1, SUPPLY);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, caller, 0, amount));
        vm.prank(caller);
        token.transferFrom(address(this), alice, amount);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(alice), 0);
    }

    function testFuzz_approveReplacesRatherThanAdds(uint256 initial, uint256 replacement) public {
        token.approve(spender, initial);
        token.approve(spender, replacement);
        assertEq(token.allowance(address(this), spender), replacement);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }
}
