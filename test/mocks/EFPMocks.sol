// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IEFPAccountMetadata} from "@efp/v1/interfaces/IEFPAccountMetadata.sol";
import {IEFPListMetadata, IEFPListRecords} from "@efp/v1/interfaces/IEFPListRecords.sol";

/// @title MockAccountMetadata
/// @notice Minimal `IEFPAccountMetadata` for tests: stores keyed bytes per address.
contract MockAccountMetadata is IEFPAccountMetadata {
    mapping(address => mapping(bytes32 => bytes)) private _values;

    function _key(string calldata key) internal pure returns (bytes32) {
        return keccak256(bytes(key));
    }

    function getValue(address addr, string calldata key) external view returns (bytes memory) {
        return _values[addr][_key(key)];
    }

    function setValueForAddress(address addr, string calldata key, bytes calldata value) external {
        _values[addr][_key(key)] = value;
        emit UpdateAccountMetadata(addr, key, value);
    }

    function addProxy(address) external pure {}

    function removeProxy(address) external pure {}

    function isProxy(address) external pure returns (bool) {
        return false;
    }

    function setValue(string calldata, bytes calldata) external pure {}

    function setValues(IEFPAccountMetadata.KeyValue[] calldata) external pure {}

    function setValuesForAddress(address, IEFPAccountMetadata.KeyValue[] calldata) external pure {}
}

/// @title MockListRecords
/// @notice Minimal `IEFPListRecords` for tests: tracks list user/manager per slot; other methods are no-ops.
contract MockListRecords is IEFPListRecords {
    mapping(uint256 => address) public listUser;
    mapping(uint256 => address) public listManager;

    function getListUser(uint256 slot) external view returns (address) {
        return listUser[slot];
    }

    function setListUser(uint256 slot, address user) external {
        listUser[slot] = user;
    }

    function getListManager(uint256 slot) external view returns (address) {
        return listManager[slot];
    }

    function setListManager(uint256 slot, address manager) external {
        listManager[slot] = manager;
    }

    function getMetadataValue(uint256, string calldata) external pure returns (bytes memory) {
        return "";
    }

    function getMetadataValues(uint256, string[] calldata keys) external pure returns (bytes[] memory out) {
        out = new bytes[](keys.length);
    }

    function setMetadataValue(uint256, string calldata, bytes calldata) external pure {}

    function setMetadataValues(uint256, IEFPListMetadata.KeyValue[] calldata) external pure {}

    function claimListManager(uint256) external pure {}

    function claimListManagerForAddress(uint256, address) external pure {}

    function getListOpCount(uint256) external pure returns (uint256) {
        return 0;
    }

    function getListOp(uint256, uint256) external pure returns (bytes memory) {
        return "";
    }

    function getListOpsInRange(uint256, uint256, uint256) external pure returns (bytes[] memory) {
        return new bytes[](0);
    }

    function getAllListOps(uint256) external pure returns (bytes[] memory) {
        return new bytes[](0);
    }

    function applyListOp(uint256, bytes calldata) external pure {}

    function applyListOps(uint256, bytes[] calldata) external pure {}

    function setMetadataValuesAndApplyListOps(uint256, IEFPListMetadata.KeyValue[] calldata, bytes[] calldata)
        external
        pure {}
}
