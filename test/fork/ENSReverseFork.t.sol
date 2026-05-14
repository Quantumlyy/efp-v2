// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {EFPListRegistryV2} from "@efp/v2/EFPListRegistryV2.sol";
import {IEFPListRegistryV2} from "@efp/v2/interfaces/IEFPListRegistryV2.sol";
import {ENS} from "@ens/registry/ENS.sol";

/**
 * @title ENSReverseForkTest
 * @notice Optional smoke test against mainnet ENS + reverse registrar. Skips when `MAINNET_RPC_URL` is unset.
 * @dev Fork tests are useful to ensure calldata matches live `IReverseRegistrar` / `ENS` layouts, but CI
 *      should not depend on them: use mocked ENS in `EFPENSReverse.t.sol` for deterministic coverage.
 */
contract ENSReverseForkTest is Test {
    address internal constant ENS_REGISTRY_MAINNET = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

    function setUp() public {
        string memory rpc = vm.envOr("MAINNET_RPC_URL", string(""));
        if (bytes(rpc).length == 0) {
            vm.skip(true);
        } else {
            vm.createSelectFork(rpc);
        }
    }

    function testFork_claimReverseENS_registry() public {
        EFPListRegistryV2 reg = new EFPListRegistryV2(address(this));
        reg.setMintState(IEFPListRegistryV2.MintState.PublicMint);
        bytes32 node = reg.claimReverseENS(ENS(ENS_REGISTRY_MAINNET), address(this));
        assertTrue(node != bytes32(0));
    }
}
