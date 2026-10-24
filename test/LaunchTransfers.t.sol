// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {HooksStoreToken} from "../src/HooksStoreToken.sol";
import {TokenFactory} from "./helpers/TokenFactory.sol";

/// @dev Checks exact ERC-20 movements for launch participants. This is not a pool/swap simulation.
contract LaunchTransfersTest is Test {
    function test_factoryDistributionClaimsAndPoolTransfersArriveWhole() public {
        TokenFactory factory = new TokenFactory();
        HooksStoreToken token = factory.deploy();
        uint256 supply = 1_000_000_000_000_000_000_000_000_000;
        address distributor = makeAddr("distributor");
        address poolManager = makeAddr("pool-manager");
        address remainderRecipient = makeAddr("remainder-recipient");
        address claimant = makeAddr("claimant");
        address trader = makeAddr("trader");

        vm.startPrank(address(factory));
        assertTrue(token.transfer(distributor, supply / 10));
        assertTrue(token.transfer(poolManager, supply * 8 / 10));
        assertTrue(token.transfer(remainderRecipient, supply / 10));
        vm.stopPrank();
        assertEq(token.balanceOf(address(factory)), 0);
        assertEq(token.balanceOf(distributor), supply / 10);
        assertEq(token.balanceOf(poolManager), supply * 8 / 10);
        assertEq(token.balanceOf(remainderRecipient), supply / 10);

        vm.prank(distributor);
        assertTrue(token.transfer(claimant, supply / 10));
        assertEq(token.balanceOf(distributor), 0);
        assertEq(token.balanceOf(claimant), supply / 10);

        vm.prank(poolManager);
        assertTrue(token.transfer(trader, 123 ether));
        assertEq(token.balanceOf(trader), 123 ether);
        assertEq(token.balanceOf(poolManager), supply * 8 / 10 - 123 ether);
        vm.prank(trader);
        assertTrue(token.transfer(poolManager, 123 ether));
        assertEq(token.balanceOf(trader), 0);
        assertEq(token.balanceOf(poolManager), supply * 8 / 10);
        assertEq(token.totalSupply(), supply);
    }
}
