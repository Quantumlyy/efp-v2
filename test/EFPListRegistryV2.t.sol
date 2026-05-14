// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";
import {IEFPListRegistryV2} from "@efp/v2/interfaces/IEFPListRegistryV2.sol";

/// @title EFPListRegistryV2Test
/// @notice Unit tests for {EFPListRegistryV2}: registration policy, pricing, pause, and ACL on storage updates.
contract EFPListRegistryV2Test is Test {
    EFPListRegistryV2 internal registry;

    address internal owner = address(this);
    address internal alice = address(0xA11CE);
    address internal bob = address(0xB0B);

    bytes internal constant LOC = hex"0101";

    function setUp() public {
        registry = new EFPListRegistryV2(owner);
    }

    function test_RevertWhen_MintingDisabled() public {
        vm.prank(alice);
        vm.expectRevert(bytes("EFPListRegistryV2: minting disabled"));
        registry.mint(LOC);
    }

    function test_Mint_SequentialIdsAndOwner() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);

        vm.expectEmit(true, false, false, true);
        emit IEFPListRegistryV2.UpdateListStorageLocation(0, LOC);

        vm.prank(alice);
        registry.mint{value: 0}(LOC);
        assertEq(registry.totalLists(), 1);
        assertEq(registry.getListOwner(0), alice);
        assertEq(registry.getListStorageLocation(0), LOC);

        vm.prank(bob);
        registry.mintTo{value: 0}(alice, LOC);
        assertEq(registry.totalLists(), 2);
        assertEq(registry.getListOwner(1), alice);
    }

    function test_RevertWhen_InsufficientPayment() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        registry.setMintPrice(1 ether);

        vm.prank(alice);
        vm.expectRevert(bytes("EFPListRegistryV2: insufficient payment"));
        registry.mint{value: 0}(LOC);
    }

    function test_Mint_WithMintPrice() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        registry.setMintPrice(0.5 ether);

        vm.deal(alice, 1 ether);
        vm.prank(alice);
        registry.mint{value: 0.5 ether}(LOC);
        assertEq(address(registry).balance, 0.5 ether);
    }

    function test_SetListStorageLocation_OnlyOwnerOfList() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        vm.prank(alice);
        registry.mint{value: 0}(LOC);

        bytes memory newLoc = hex"0101abcd";

        vm.prank(bob);
        vm.expectRevert(bytes("EFPListRegistryV2: not list owner"));
        registry.setListStorageLocation(0, newLoc);

        vm.prank(alice);
        registry.setListStorageLocation(0, newLoc);
        assertEq(registry.getListStorageLocation(0), newLoc);
    }

    function test_RevertWhen_PausedMint() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        registry.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Pausable.EnforcedPause.selector));
        registry.mint{value: 0}(LOC);
    }

    /// @dev Fuzz tuned per handbook: bound payment and price to avoid junk reverts, assert monotonic payment rule.
    function testFuzz_Mint_RequiresPaymentAtLeastMintPrice(uint256 priceWei, uint256 payWei) public {
        priceWei = bound(priceWei, 0, 5 ether);
        payWei = bound(payWei, 0, 5 ether);

        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        registry.setMintPrice(priceWei);
        vm.deal(alice, payWei);

        vm.prank(alice);
        if (payWei < priceWei) {
            vm.expectRevert(bytes("EFPListRegistryV2: insufficient payment"));
            registry.mint{value: payWei}(LOC);
        } else {
            registry.mint{value: payWei}(LOC);
            assertEq(registry.totalLists(), 1);
            assertEq(registry.getListOwner(0), alice);
            assertEq(address(registry).balance, payWei);
        }
    }

    function test_OwnerOnly_MintState() public {
        registry.setMintState(IEFPListRegistryV2.MintState.OwnerOnly);

        vm.prank(alice);
        vm.expectRevert(bytes("EFPListRegistryV2: owner only"));
        registry.mint{value: 0}(LOC);

        registry.mint{value: 0}(LOC);
        assertEq(registry.getListOwner(0), owner);
    }

    function test_Withdraw() public {
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        registry.setMintPrice(1 wei);
        vm.deal(alice, 10 wei);
        vm.prank(alice);
        registry.mint{value: 1 wei}(LOC);

        address payable recipient = payable(address(0xC0FFEE));
        uint256 bBefore = recipient.balance;
        registry.withdraw(recipient, 1 wei);
        assertEq(recipient.balance, bBefore + 1 wei);
    }
}
