// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {EFPListEntryV2} from "@efp/v2/EFPListEntryV2.sol";
import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";
import {IEFPListRegistryV2} from "@efp/v2/interfaces/IEFPListRegistryV2.sol";

import {MockAccountMetadata, MockListRecords} from "./mocks/EFPMocks.sol";

/// @title EFPListEntryV2Test
/// @notice Integration-style tests for {EFPListEntryV2} against registry + mocks.
contract EFPListEntryV2Test is Test {
    EFPListRegistryV2 internal registry;
    MockAccountMetadata internal metadata;
    MockListRecords internal records;
    EFPListEntryV2 internal entry;

    address internal deployer = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    uint256 internal constant SLOT = 42;

    function setUp() public {
        metadata = new MockAccountMetadata();
        records = new MockListRecords();
        registry = new EFPListRegistryV2(deployer);
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        entry = new EFPListEntryV2(deployer, address(registry), address(metadata), address(records));
    }

    function encodeL1(uint256 chainId, address recordsAddr, uint256 slot) internal pure returns (bytes memory) {
        return bytes.concat(bytes1(0x01), bytes1(0x01), bytes32(chainId), bytes20(uint160(recordsAddr)), bytes32(slot));
    }

    function test_BootstrapList_SetsPrimaryListAndRecords() public {
        bytes memory loc = encodeL1(block.chainid, address(records), SLOT);
        assertEq(loc.length, 86);

        vm.prank(alice);
        entry.bootstrapList{value: 0}(loc);

        assertEq(registry.totalLists(), 1);
        assertEq(registry.getListOwner(0), alice);
        assertEq(registry.getListStorageLocation(0), loc);
        assertEq(metadata.getValue(alice, "primary-list"), abi.encodePacked(uint256(0)));
        assertEq(records.getListUser(SLOT), alice);
        assertEq(records.getListManager(SLOT), alice);
    }

    function test_BootstrapList_DifferentRecordsContract_SkipsRecordsWiring() public {
        address other = address(0x1234);
        bytes memory loc = encodeL1(block.chainid, other, SLOT);

        vm.prank(alice);
        entry.bootstrapList{value: 0}(loc);

        assertEq(records.getListUser(SLOT), address(0));
        assertEq(records.getListManager(SLOT), address(0));
    }

    function test_BootstrapListTo_MintsToBob_SetsPrimaryForCaller() public {
        bytes memory loc = encodeL1(block.chainid, address(records), SLOT);

        vm.prank(alice);
        entry.bootstrapListTo{value: 0}(bob, loc);

        assertEq(registry.getListOwner(0), bob);
        assertEq(metadata.getValue(alice, "primary-list"), abi.encodePacked(uint256(0)));
        assertEq(metadata.getValue(bob, "primary-list"), "");
        assertEq(records.getListUser(SLOT), alice);
    }

    function test_DecodeL1_ReturnsSlotAndRecordsContract() public view {
        address target = address(0x1111);
        uint256 slot = 7;
        bytes memory loc = encodeL1(block.chainid, target, slot);
        (uint256 gotSlot, address gotRecords) = entry.decodeL1ListStorageLocation(loc);
        assertEq(gotSlot, slot);
        assertEq(gotRecords, target);
    }

    function test_DecodeL1_RevertsOnBadLength() public {
        vm.expectRevert(bytes("EFPListEntryV2: invalid list storage location length"));
        entry.decodeL1ListStorageLocation(hex"0101");
    }

    function test_DecodeL1_RevertsOnBadVersion() public {
        bytes memory loc = encodeL1(block.chainid, address(records), SLOT);
        loc[0] = 0x02;
        vm.expectRevert(bytes("EFPListEntryV2: invalid list storage location version"));
        entry.decodeL1ListStorageLocation(loc);
    }

    function test_DecodeL1_RevertsOnBadLocationType() public {
        bytes memory loc = encodeL1(block.chainid, address(records), SLOT);
        loc[1] = 0x02;
        vm.expectRevert(bytes("EFPListEntryV2: invalid list storage location type"));
        entry.decodeL1ListStorageLocation(loc);
    }

    function test_RevertWhen_EntryPaused_BootstrapList() public {
        bytes memory loc = encodeL1(block.chainid, address(records), SLOT);
        entry.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        entry.bootstrapList{value: 0}(loc);
    }

    function test_DecodeL1_RevertsOnChainIdMismatch() public {
        uint256 wrongChain = block.chainid == 1 ? 2 : 1;
        bytes memory loc = encodeL1(wrongChain, address(records), SLOT);
        vm.expectRevert(bytes("EFPListEntryV2: chain id mismatch"));
        entry.decodeL1ListStorageLocation(loc);
    }

    function test_BootstrapList_RevertsOnChainIdMismatch() public {
        uint256 wrongChain = block.chainid == 1 ? 2 : 1;
        bytes memory loc = encodeL1(wrongChain, address(records), SLOT);
        vm.prank(alice);
        vm.expectRevert(bytes("EFPListEntryV2: chain id mismatch"));
        entry.bootstrapList{value: 0}(loc);
    }
}
