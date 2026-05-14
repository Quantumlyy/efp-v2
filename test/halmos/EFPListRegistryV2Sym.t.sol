// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";

import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";
import {IEFPListRegistryV2} from "@efp/v2/interfaces/IEFPListRegistryV2.sol";

/**
 * @title EFPListRegistryV2SymTest
 * @notice Symbolic tests for {EFPListRegistryV2}. Run with Halmos, not `forge test`
 *         (functions use the `check_*` prefix per the Halmos guide).
 * @dev Run `forge clean && forge build --ast` before `halmos` so artifacts include the compiler AST
 *      (incremental builds without `--ast` leave JSON that Halmos cannot load).
 *      Halmos guide: https://github.com/a16z/halmos/blob/main/docs/getting-started.md
 */
contract EFPListRegistryV2SymTest is SymTest, Test {
    EFPListRegistryV2 internal registry;

    function setUp() public {
        registry = new EFPListRegistryV2(address(this));
        registry.setMintState(IEFPListRegistryV2.MintState.PublicMint);
    }

    /**
     * @notice If `pay >= mintPrice` and caller is a non-zero non-owner account, `mint` allocates list 0
     *         to that account and keeps the full `pay` balance on the registry.
     * @dev Uses `vm.assume` (not `bound`) for symbolic efficiency per Halmos docs.
     */
    function check_mint_assigns_owner_and_retains_balance(address alice, uint256 mintPrice, uint256 pay) public {
        vm.assume(alice != address(0) && alice != address(this));
        vm.assume(pay >= mintPrice);

        registry.setMintPrice(mintPrice);
        bytes memory loc = svm.createBytes(86, "listStorageLocation");

        vm.deal(alice, pay);
        vm.prank(alice);
        registry.mint{value: pay}(loc);

        assert(registry.totalLists() == 1);
        assert(registry.getListOwner(0) == alice);
        assert(address(registry).balance == pay);
        assert(keccak256(registry.getListStorageLocation(0)) == keccak256(loc));
    }

    /**
     * @notice When `mintPrice > 0` and `pay < mintPrice`, `mint` must fail and no list is created.
     * @dev Halmos ignores ordinary reverts on external calls; use a low-level call and assert `!success`
     *      as in the Halmos getting-started guide.
     */
    function check_mint_reverts_when_underpaid(address alice, uint256 mintPrice, uint256 pay) public {
        vm.assume(alice != address(0) && alice != address(this));
        vm.assume(mintPrice > 0 && pay < mintPrice);

        registry.setMintPrice(mintPrice);
        bytes memory loc = svm.createBytes(86, "listStorageLocation");

        vm.deal(alice, pay);
        vm.prank(alice);
        (bool success,) =
            address(registry).call{value: pay}(abi.encodeWithSelector(EFPListRegistryV2.mint.selector, loc));

        assert(!success);
        assert(registry.totalLists() == 0);
    }
}
