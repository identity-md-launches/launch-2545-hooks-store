// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {HooksStoreToken} from "src/HooksStoreToken.sol";

/// @dev Regression cases and properties complementing the existing ERC-20 suite.
/// All funding uses real transfers of the constructor supply, never storage writes.
/// forge-config: default.fuzz.runs = 1000
contract HooksStoreTokenEdgesTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;

    HooksStoreToken private token;
    address private alice;
    address private bob;
    address private spender;

    function setUp() public {
        token = new HooksStoreToken();
        alice = makeAddr("edge-alice");
        bob = makeAddr("edge-bob");
        spender = makeAddr("edge-spender");
    }

    function test_oneWeiCanMoveAndBeSpentExactlyOnce() public {
        assertTrue(token.transfer(alice, 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, 1));
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, 1));

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.allowance(alice, spender), 0);

        // Return the balance so the second spend fails solely for lack of approval.
        vm.prank(bob);
        assertTrue(token.transfer(alice, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumFiniteAllowanceIsConsumed() public {
        uint256 approved = type(uint256).max - 1;
        assertTrue(token.approve(spender, approved));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, SUPPLY));

        assertEq(token.allowance(address(this), spender), approved - SUPPLY);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.balanceOf(alice), SUPPLY);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_maximumSpendWithInfiniteApprovalStillRequiresBalance() public {
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

    function test_selfTransferCannotBypassBalanceCheck() public {
        assertTrue(token.transfer(alice, 3));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 3, 4));
        vm.prank(alice);
        token.transfer(alice, 4);
        assertEq(token.balanceOf(alice), 3);

        vm.prank(alice);
        assertTrue(token.approve(spender, 4));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 3, 4));
        vm.prank(spender);
        token.transferFrom(alice, alice, 4);
        assertEq(token.balanceOf(alice), 3);
        assertEq(token.allowance(alice, spender), 4);
        assertEq(token.balanceOf(address(this)), SUPPLY - 3);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroValueDoesNotMakeZeroRecipientValid() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 0);

        assertTrue(token.approve(spender, 1));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), 0);
        assertEq(token.allowance(address(this), spender), 1);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_zeroValueDoesNotMakeZeroSpenderValid() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 0);
        assertEq(token.allowance(address(this), address(0)), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    /// @dev Exercises the library's zero-caller guards; this is not an on-chain impersonation claim.
    function test_zeroCallerCannotTransferOrApproveEvenZero() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        vm.prank(address(0));
        token.transfer(alice, 0);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        vm.prank(address(0));
        token.approve(spender, 0);
        assertEq(token.allowance(address(0), spender), 0);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function test_infiniteApprovalCanBeReplacedWithFiniteAndRevokedAfterSpend() public {
        assertTrue(token.approve(spender, type(uint256).max));
        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), alice, 1));
        assertTrue(token.approve(spender, 3));
        assertEq(token.allowance(address(this), spender), 3);

        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, 2));
        assertEq(token.allowance(address(this), spender), 1);
        assertTrue(token.approve(spender, 0));
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(address(this), bob, 1);

        assertEq(token.allowance(address(this), spender), 0);
        assertEq(token.balanceOf(address(this)), SUPPLY - 3);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 2);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_finiteBudgetCannotBeOverspent(uint256 budget, uint256 firstSpend) public {
        budget = bound(budget, 0, SUPPLY - 1);
        firstSpend = bound(firstSpend, 0, budget);
        assertTrue(token.transfer(alice, budget + 1));
        vm.prank(alice);
        assertTrue(token.approve(spender, budget));

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, budget, budget + 1)
        );
        vm.prank(spender);
        token.transferFrom(alice, bob, budget + 1);
        assertEq(token.balanceOf(alice), budget + 1);
        assertEq(token.balanceOf(bob), 0);
        assertEq(token.allowance(alice, spender), budget);

        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, firstSpend));
        assertEq(token.allowance(alice, spender), budget - firstSpend);
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, budget - firstSpend));
        assertEq(token.allowance(alice, spender), 0);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, spender, 0, 1));
        vm.prank(spender);
        token.transferFrom(alice, bob, 1);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), budget);
        assertEq(token.balanceOf(address(this)), SUPPLY - budget - 1);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_failedSpendCanBeRetriedAfterFunding(uint256 balance, uint256 amount, uint256 approved) public {
        balance = bound(balance, 0, SUPPLY - 1);
        amount = bound(amount, balance + 1, SUPPLY);
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
        assertEq(token.totalSupply(), SUPPLY);

        assertTrue(token.transfer(alice, amount - balance));
        // The original allowance must still authorize the entire retry.
        vm.prank(spender);
        assertTrue(token.transferFrom(alice, bob, amount));
        assertEq(token.allowance(alice, spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_invalidRecipientDoesNotConsumeApproval(uint256 amount, uint256 approved) public {
        amount = bound(amount, 0, SUPPLY);
        approved = bound(approved, amount, type(uint256).max);
        assertTrue(token.approve(spender, approved));

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(spender);
        token.transferFrom(address(this), address(0), amount);
        assertEq(token.allowance(address(this), spender), approved);
        assertEq(token.balanceOf(address(this)), SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.totalSupply(), SUPPLY);

        vm.prank(spender);
        assertTrue(token.transferFrom(address(this), bob, amount));
        assertEq(token.balanceOf(bob), amount);
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.allowance(address(this), spender), approved == type(uint256).max ? approved : approved - amount);
    }

    function testFuzz_roundTripRestoresBothPreexistingBalances(uint256 aliceBalance, uint256 amount) public {
        aliceBalance = bound(aliceBalance, 0, SUPPLY);
        amount = bound(amount, 0, aliceBalance);
        assertTrue(token.transfer(alice, aliceBalance));
        assertTrue(token.transfer(bob, SUPPLY - aliceBalance));

        vm.prank(alice);
        assertTrue(token.transfer(bob, amount));
        assertEq(token.balanceOf(alice), aliceBalance - amount);
        assertEq(token.balanceOf(bob), SUPPLY - aliceBalance + amount);
        vm.prank(bob);
        assertTrue(token.transfer(alice, amount));
        assertEq(token.balanceOf(alice), aliceBalance);
        assertEq(token.balanceOf(bob), SUPPLY - aliceBalance);
        assertEq(token.balanceOf(address(this)), 0);
        assertEq(token.totalSupply(), SUPPLY);
    }

    function testFuzz_splitDelegatedSpendMatchesSingleSpend(uint256 amount, uint256 firstSpend, uint256 approved)
        public
    {
        amount = bound(amount, 1, SUPPLY);
        firstSpend = bound(firstSpend, 0, amount);
        approved = bound(approved, amount, type(uint256).max);
        HooksStoreToken singleSpendToken = new HooksStoreToken();

        assertTrue(token.approve(spender, approved));
        assertTrue(singleSpendToken.approve(spender, approved));
        vm.startPrank(spender);
        assertTrue(token.transferFrom(address(this), alice, firstSpend));
        assertTrue(token.transferFrom(address(this), alice, amount - firstSpend));
        assertTrue(singleSpendToken.transferFrom(address(this), alice, amount));
        vm.stopPrank();

        assertEq(token.balanceOf(address(this)), singleSpendToken.balanceOf(address(this)));
        assertEq(token.balanceOf(alice), singleSpendToken.balanceOf(alice));
        assertEq(token.allowance(address(this), spender), singleSpendToken.allowance(address(this), spender));
        assertEq(token.balanceOf(address(this)), SUPPLY - amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(token.allowance(address(this), spender), approved == type(uint256).max ? approved : approved - amount);
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(singleSpendToken.totalSupply(), SUPPLY);
    }
}
