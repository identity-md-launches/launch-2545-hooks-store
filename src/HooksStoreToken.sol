// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Hooks Store (HOOKS)
/// @notice A fixed supply of one billion tokens, with 18 decimals, minted to the deployer.
/// @dev The immediate creator receives the entire supply, including when created by a factory.
/// There are no external mint, burn, administrative, or upgrade functions.
contract HooksStoreToken is ERC20 {
    /// @notice The entire supply in the token's smallest units (10^27).
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    constructor() ERC20("Hooks Store", "HOOKS") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
