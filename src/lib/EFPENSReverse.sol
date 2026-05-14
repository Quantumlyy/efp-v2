// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "@ens/registry/ENS.sol";
import {IReverseRegistrar} from "@ens/reverseRegistrar/IReverseRegistrar.sol";

/**
 * @title EFPENSReverse
 * @notice Internal helpers to configure reverse ENS for **this contract’s address**, matching the v1
 *         [`ENSReverseClaimer`](https://github.com/ethereumfollowprotocol/contracts) behavior but using
 *         interfaces from [ens-contracts](https://github.com/ensdomains/ens-contracts) (imported via the Foundry `ens` remapping).
 * @dev `claim` / `setName` on the default reverse registrar apply to `msg.sender` of the subcall,
 *      i.e. the contract that includes these helpers when the owner triggers them.
 */
library EFPENSReverse {
    /// @dev namehash("addr.reverse") — domain under which per-address reverse records live.
    bytes32 internal constant ADDR_REVERSE_NODE = 0x91d1777781884d03a6757a803996e38de2a42967fb37eeaca72729271025a9e2;

    /// @dev Resolves the default reverse registrar from `ens.owner(ADDR_REVERSE_NODE)` then calls `claim`.
    function claimReverseENS(ENS ens, address claimant) internal returns (bytes32) {
        address registrar = ens.owner(ADDR_REVERSE_NODE);
        return IReverseRegistrar(registrar).claim(claimant);
    }

    /// @dev Resolves the default reverse registrar then calls `setName` for this contract’s address.
    function setReverseENS(ENS ens, string calldata name) internal returns (bytes32) {
        address registrar = ens.owner(ADDR_REVERSE_NODE);
        return IReverseRegistrar(registrar).setName(name);
    }
}
