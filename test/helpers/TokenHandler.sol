// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HooksStoreToken} from "../../src/HooksStoreToken.sol";

/// @dev Test-only independent ledger. Actions include insufficient funds, missing approval,
/// zero recipients, self-transfers, and finite/infinite allowances in arbitrary sequences.
contract TokenHandler is Test {
    HooksStoreToken private immutable token;
    address[4] private actors;
    mapping(address => uint256) public expectedBalance;
    mapping(address => mapping(address => uint256)) public expectedAllowance;

    constructor(HooksStoreToken token_, address[4] memory actors_) {
        token = token_;
        actors = actors_;
        expectedBalance[actors_[0]] = token_.totalSupply();
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

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
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

    function transferFrom(uint256 ownerSeed, uint256 toSeed, uint256 spenderSeed, uint256 amountSeed) external {
        address owner = actors[ownerSeed % actors.length];
        address to = _recipient(toSeed);
        address spender = actors[spenderSeed % actors.length];
        uint256 amount = bound(amountSeed, 0, expectedBalance[owner] + 1);
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
