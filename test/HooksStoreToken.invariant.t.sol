// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {HooksStoreToken} from "../src/HooksStoreToken.sol";
import {TokenHandler} from "./helpers/TokenHandler.sol";

/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 128
/// forge-config: default.invariant.fail-on-revert = true
contract HooksStoreTokenInvariantTest is Test {
    uint256 private constant SUPPLY = 1_000_000_000_000_000_000_000_000_000;

    HooksStoreToken private token;
    TokenHandler private handler;
    address[4] private actors;

    function setUp() public {
        token = new HooksStoreToken();
        actors = [makeAddr("holder-a"), makeAddr("holder-b"), makeAddr("holder-c"), makeAddr("holder-d")];
        handler = new TokenHandler(token, actors);
        assertTrue(token.transfer(actors[0], SUPPLY));

        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = TokenHandler.transfer.selector;
        selectors[1] = TokenHandler.approve.selector;
        selectors[2] = TokenHandler.transferFrom.selector;
        selectors[3] = TokenHandler.approveBoundary.selector;
        selectors[4] = TokenHandler.transferFromBoundary.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function test_handlerReplaysExhaustionFailureAndRefill() public {
        // Approve one wei and fail to spend two. The failed call must not consume it.
        handler.approveBoundary(0, 1, 1, 0);
        handler.transferFromBoundary(0, 2, 1, 2, 0);
        assertEq(token.allowance(actors[0], actors[1]), 1);
        invariant_balancesAndAllowancesMatchIndependentLedger();
        invariant_supplyIsFixedAndAllTokensAreAccountedFor();

        handler.transferFromBoundary(0, 2, 1, 1, 0);
        assertEq(token.balanceOf(actors[2]), 1);
        assertEq(token.allowance(actors[0], actors[1]), 0);
        handler.transferFromBoundary(0, 2, 1, 2, 0);
        invariant_balancesAndAllowancesMatchIndependentLedger();
        invariant_supplyIsFixedAndAllTokensAreAccountedFor();

        // Refill the budget with an infinite approval, then revoke it after spending.
        handler.approveBoundary(0, 1, 4, 0);
        handler.transferFromBoundary(0, 2, 1, 1, 0);
        assertEq(token.balanceOf(actors[2]), SUPPLY);
        assertEq(token.allowance(actors[0], actors[1]), type(uint256).max);
        handler.approveBoundary(0, 1, 0, 0);
        handler.transfer(2, 0, SUPPLY);
        handler.transferFromBoundary(0, 2, 1, 2, 0);
        assertEq(token.balanceOf(actors[0]), SUPPLY);
        assertEq(token.allowance(actors[0], actors[1]), 0);
        invariant_balancesAndAllowancesMatchIndependentLedger();
        invariant_supplyIsFixedAndAllTokensAreAccountedFor();
    }

    function invariant_supplyIsFixedAndAllTokensAreAccountedFor() public view {
        uint256 balanceSum;
        for (uint256 i; i < actors.length; ++i) {
            balanceSum += token.balanceOf(actors[i]);
        }
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(balanceSum, SUPPLY);
        assertEq(token.balanceOf(address(0)), 0);
        assertEq(token.balanceOf(address(token)), 0);
        assertEq(token.balanceOf(address(handler)), 0);
        assertEq(token.balanceOf(address(this)), 0);
    }

    function invariant_balancesAndAllowancesMatchIndependentLedger() public view {
        for (uint256 i; i < actors.length; ++i) {
            address owner = actors[i];
            assertEq(token.balanceOf(owner), handler.expectedBalance(owner));
            assertEq(token.allowance(owner, address(0)), 0);
            for (uint256 j; j < actors.length; ++j) {
                address spender = actors[j];
                assertEq(token.allowance(owner, spender), handler.expectedAllowance(owner, spender));
            }
        }
    }
}
