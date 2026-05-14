// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "@ens/registry/ENS.sol";
import {IReverseRegistrar} from "@ens/reverseRegistrar/IReverseRegistrar.sol";

/// @notice Minimal ENS registry for tests: configurable `owner(bytes32)`; other methods revert.
contract MockENS is ENS {
    mapping(bytes32 => address) internal _owners;

    function setNodeOwner(bytes32 node, address o) external {
        _owners[node] = o;
    }

    function owner(bytes32 node) external view returns (address) {
        return _owners[node];
    }

    function setRecord(bytes32, address, address, uint64) external pure {
        revert("MockENS");
    }

    function setSubnodeRecord(bytes32, bytes32, address, address, uint64) external pure {
        revert("MockENS");
    }

    function setSubnodeOwner(bytes32, bytes32, address) external pure returns (bytes32) {
        revert("MockENS");
    }

    function setResolver(bytes32, address) external pure {
        revert("MockENS");
    }

    function setOwner(bytes32, address) external pure {
        revert("MockENS");
    }

    function setTTL(bytes32, uint64) external pure {
        revert("MockENS");
    }

    function setApprovalForAll(address, bool) external pure {
        revert("MockENS");
    }

    function resolver(bytes32) external pure returns (address) {
        return address(0);
    }

    function ttl(bytes32) external pure returns (uint64) {
        return 0;
    }

    function recordExists(bytes32) external pure returns (bool) {
        return false;
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return false;
    }
}

/// @notice Captures `claim` / `setName` calls for assertions; other IReverseRegistrar methods revert.
contract MockReverseRegistrar is IReverseRegistrar {
    address public lastClaimOwnerArg;
    address public lastClaimMsgSender;
    string public lastSetName;

    function setDefaultResolver(address) external pure {}

    function claim(address owner_) external returns (bytes32) {
        lastClaimOwnerArg = owner_;
        lastClaimMsgSender = msg.sender;
        return keccak256(abi.encodePacked(msg.sender, owner_));
    }

    function claimForAddr(address, address, address) external pure returns (bytes32) {
        revert("MockReverseRegistrar");
    }

    function claimWithResolver(address, address) external pure returns (bytes32) {
        revert("MockReverseRegistrar");
    }

    function setName(string memory name) external returns (bytes32) {
        lastSetName = name;
        lastClaimMsgSender = msg.sender;
        return keccak256(bytes(name));
    }

    function setNameForAddr(address, address, address, string memory) external pure returns (bytes32) {
        revert("MockReverseRegistrar");
    }

    function node(address) external pure returns (bytes32) {
        return bytes32(0);
    }
}
