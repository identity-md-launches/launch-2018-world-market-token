// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title World Market Token
/// @notice Fixed-supply ERC-20: one billion WORLD, with 18 decimals.
/// @dev The immediate deployer receives the entire supply. There are no administrative powers
///      or externally callable mint/burn functions, and transfers use unmodified ERC-20 behavior.
contract WorldMarketToken is ERC20 {
    /// @notice The one-time issuance in the token's smallest units (10^27).
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    /// @dev For a factory deployment, msg.sender is the factory, which receives all tokens.
    constructor() ERC20("World Market Token", "WORLD") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
