// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {WorldMarketToken} from "../../src/WorldMarketToken.sol";

/// @dev Test-only factory; never part of the launch's application contracts.
contract TokenFactoryProbe {
    function deploy(bytes32 salt) external returns (WorldMarketToken) {
        return new WorldMarketToken{salt: salt}();
    }
}
