// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {HooksStoreToken} from "../../src/HooksStoreToken.sol";

/// @dev Test-only factory to verify the constructor's immediate-caller semantics.
contract TokenFactory {
    function deploy() external returns (HooksStoreToken) {
        return new HooksStoreToken();
    }

    function deployDeterministic(bytes32 salt) external returns (HooksStoreToken) {
        return new HooksStoreToken{salt: salt}();
    }
}
