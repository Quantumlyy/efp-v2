// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ENS} from "@ens/registry/ENS.sol";

import {EFPListEntryV2} from "@efp/v2/EFPListEntryV2.sol";
import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";
import {EFPENSReverse} from "@efp/v2/lib/EFPENSReverse.sol";
import {IEFPListRegistryV2} from "@efp/v2/interfaces/IEFPListRegistryV2.sol";

import {MockAccountMetadata, MockListRecords} from "./mocks/EFPMocks.sol";
import {MockENS, MockReverseRegistrar} from "./mocks/ENSMocks.sol";

/// @title EFPENSReverseTest
/// @notice Unit tests for owner-only reverse ENS wrappers on registry and entry (mock ENS + registrar).
contract EFPENSReverseTest is Test {
    MockENS internal ens;
    MockReverseRegistrar internal reverse;
    EFPListRegistryV2 internal registry;
    EFPListEntryV2 internal entry;

    address internal deployer = address(this);
    address internal alice = address(0xA11CE);

    function setUp() public {
        ens = new MockENS();
        reverse = new MockReverseRegistrar();
        ens.setNodeOwner(EFPENSReverse.ADDR_REVERSE_NODE, address(reverse));

        registry = new EFPListRegistryV2(deployer);
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);

        MockAccountMetadata metadata = new MockAccountMetadata();
        MockListRecords records = new MockListRecords();
        entry = new EFPListEntryV2(deployer, address(registry), address(metadata), address(records));
    }

    function test_Registry_claimReverseENS_forwardsToRegistrar() public {
        registry.claimReverseENS(ENS(address(ens)), alice);
        assertEq(reverse.lastClaimMsgSender(), address(registry));
        assertEq(reverse.lastClaimOwnerArg(), alice);
    }

    function test_Registry_setReverseENS_forwardsToRegistrar() public {
        registry.setReverseENS(ENS(address(ens)), "efp.registry.v2.eth");
        assertEq(reverse.lastSetName(), "efp.registry.v2.eth");
        assertEq(reverse.lastClaimMsgSender(), address(registry));
    }

    function test_Entry_claimReverseENS_forwardsToRegistrar() public {
        entry.claimReverseENS(ENS(address(ens)), alice);
        assertEq(reverse.lastClaimMsgSender(), address(entry));
        assertEq(reverse.lastClaimOwnerArg(), alice);
    }

    function test_Entry_setReverseENS_forwardsToRegistrar() public {
        entry.setReverseENS(ENS(address(ens)), "efp.entry.v2.eth");
        assertEq(reverse.lastSetName(), "efp.entry.v2.eth");
        assertEq(reverse.lastClaimMsgSender(), address(entry));
    }

    function test_RevertWhen_NotOwner_Registry() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        registry.claimReverseENS(ENS(address(ens)), alice);
    }

    function test_RevertWhen_NotOwner_Entry() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        entry.setReverseENS(ENS(address(ens)), "x");
    }
}
