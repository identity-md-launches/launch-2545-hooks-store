// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HooksStoreToken} from "../../src/HooksStoreToken.sol";

/// @dev Test-only independent ledger. Actions include insufficient funds, missing approval,
/// zero recipients, self-transfers, and finite/infinite allowances in arbitrary sequences.
contract TokenHandler is Test {
    uint256 private constant SUPPLY = 1_000_000_000 * 10 ** 18;

    HooksStoreToken private immutable token;
    address[4] private actors;
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(HooksStoreToken token_, address[4] memory actors_) {
        token = token_;
        actors = actors_;
        expectedBalance[actors_[0]] = SUPPLY;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = _recipient(toSeed);
        uint256 amount = bound(amountSeed, 0, expectedBalance[from] + 1);
        bool shouldSucceed = to != address(0) && amount <= expectedBalance[from];

        vm.prank(from);
        (bool success, bytes memory result) = address(token).call(abi.encodeCall(IERC20.transfer, (to, amount)));
        assertEq(success, shouldSucceed, "transfer authorization or balance check disagrees with model");
        if (success) {
            assertTrue(abi.decode(result, (bool)));
            expectedBalance[from] -= amount;
            expectedBalance[to] += amount;
        }
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) public {
        address owner = actors[ownerSeed % actors.length];
        address spender = _recipient(spenderSeed);

        vm.prank(owner);
        (bool success, bytes memory result) = address(token).call(abi.encodeCall(IERC20.approve, (spender, amount)));
        assertEq(success, spender != address(0), "approve accepted an invalid spender or rejected a valid one");
        if (success) {
            assertTrue(abi.decode(result, (bool)));
            expectedAllowance[owner][spender] = amount;
        }
    }

    /// @dev Keep unrestricted approvals above, but also frequently create revocations,
    /// spendable finite budgets, and the two sides of the infinite-allowance boundary.
    function approveBoundary(uint256 ownerSeed, uint256 spenderSeed, uint8 kind, uint256 amountSeed) external {
        uint256 balance = expectedBalance[actors[ownerSeed % actors.length]];
        uint256 mode = kind % 7;
        uint256 amount;
        if (mode == 0) amount = 0;
        else if (mode == 1) amount = 1;
        else if (mode == 2) amount = balance;
        else if (mode == 3) amount = balance + 1;
        else if (mode == 4) amount = type(uint256).max;
        else if (mode == 5) amount = type(uint256).max - 1;
        else amount = bound(amountSeed, 0, SUPPLY);

        approve(ownerSeed, spenderSeed % actors.length, amount);
    }

    function transferFrom(uint256 ownerSeed, uint256 toSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address to = _recipient(toSeed);
        address spender = actors[spenderSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, expectedBalance[owner] + 1);
        _transferFrom(owner, to, spender, amount);
    }

    /// @dev Exhaust the current budget or exceed it by exactly one, regardless of
    /// previous randomized actions. No new approval is issued before the spend.
    function transferFromBoundary(
        uint256 ownerSeed,
        uint256 toSeed,
        uint256 spenderSeed,
        uint8 kind,
        uint256 amountSeed
    ) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];
        uint256 limit = expectedBalance[owner];
        if (expectedAllowance[owner][spender] < limit) limit = expectedAllowance[owner][spender];
        uint256 mode = kind % 5;
        uint256 amount;
        if (mode == 0) amount = 0;
        else if (mode == 1) amount = limit;
        else if (mode == 2) amount = limit + 1;
        else if (mode == 3) amount = type(uint256).max;
        else amount = bound(amountSeed, 0, limit);

        _transferFrom(owner, _recipient(toSeed), spender, amount);
    }

    function _transferFrom(address owner, address to, address spender, uint256 amount) private {
        uint256 approved = expectedAllowance[owner][spender];
        bool shouldSucceed = to != address(0) && amount <= expectedBalance[owner] && amount <= approved;

        vm.prank(spender);
        (bool success, bytes memory result) =
            address(token).call(abi.encodeCall(IERC20.transferFrom, (owner, to, amount)));
        assertEq(success, shouldSucceed, "transferFrom authorization or balance check disagrees with model");
        if (success) {
            assertTrue(abi.decode(result, (bool)));
            expectedBalance[owner] -= amount;
            expectedBalance[to] += amount;
            if (approved != type(uint256).max) {
                expectedAllowance[owner][spender] -= amount;
            }
        }
    }

    function _recipient(uint256 seed) private view returns (address) {
        uint256 index = seed % (actors.length + 1);
        return index == actors.length ? address(0) : actors[index];
    }
}
