// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ENS} from "@ens/registry/ENS.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEFPAccountMetadata} from "@efp/v1/interfaces/IEFPAccountMetadata.sol";
import {IEFPListRecords} from "@efp/v1/interfaces/IEFPListRecords.sol";

import {IEFPListRegistryV2} from "./interfaces/IEFPListRegistryV2.sol";
import {EFPENSReverse} from "./lib/EFPENSReverse.sol";

/**
 * @title EFPListEntryV2
 * @notice User-facing “happy path” contract: validates an L1-shaped list location, registers a list in
 *         the v2 registry, writes the caller’s `primary-list` pointer in account metadata, and optionally
 *         claims the list slot on the configured L1 `IEFPListRecords` contract.
 *
 * @dev This is the non-NFT analogue of v1 [`EFPListMinter`](https://github.com/ethereumfollowprotocol/contracts):
 *      it targets `IEFPListRegistryV2` instead of an ERC-721 registry and exposes the same optional
 *      owner-only reverse-ENS helpers via {EFPENSReverse} and the ens-contracts `ENS` / `IReverseRegistrar`
 *      types. Forwarded `msg.value`
 *      is passed through to `registry.mintTo` so the registry’s
 *      `mintPrice` (if any) can be paid in one transaction.
 *
 *      **Bootstrap semantics** mirror v1 `easyMint` / `easyMintTo`: the list id used for `primary-list` is
 *      captured as `registry.totalLists()` immediately before the minting call, matching the historical
 *      `totalSupply()` snapshot behavior.
 */
contract EFPListEntryV2 is Ownable, Pausable {
    /// @notice V2 registry that allocates numeric list ids and stores each list’s location bytes.
    IEFPListRegistryV2 public immutable registry;

    /// @notice Account metadata contract (typically v1-compatible) for `primary-list`.
    IEFPAccountMetadata public immutable accountMetadata;

    /// @notice L1 list records contract; when the encoded location points here, user/manager are set.
    IEFPListRecords public immutable listRecordsL1;

    /**
     * @param initialOwner Owner allowed to `pause` / `unpause` this entry contract.
     * @param registry_ Address of {EFPListRegistryV2}.
     * @param accountMetadata_ `IEFPAccountMetadata` used for default list bookkeeping.
     * @param listRecordsL1_ Canonical L1 `IEFPListRecords` referenced in locations you want auto-wired.
     */
    constructor(address initialOwner, address registry_, address accountMetadata_, address listRecordsL1_)
        Ownable(initialOwner)
    {
        registry = IEFPListRegistryV2(registry_);
        accountMetadata = IEFPAccountMetadata(accountMetadata_);
        listRecordsL1 = IEFPListRecords(listRecordsL1_);
    }

    /// @notice Pauses bootstrap entrypoints (`whenNotPaused`). Distinct from registry `MintState`.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses this entry contract after {pause}.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Claims this contract’s reverse ENS record for `claimant` (see {EFPENSReverse}).
    function claimReverseENS(ENS ens, address claimant) external onlyOwner returns (bytes32) {
        return EFPENSReverse.claimReverseENS(ens, claimant);
    }

    /// @notice Sets this contract’s reverse ENS name (see {EFPENSReverse}).
    function setReverseENS(ENS ens, string calldata name) external onlyOwner returns (bytes32) {
        return EFPENSReverse.setReverseENS(ens, name);
    }

    /**
     * @notice Parses the canonical L1 list storage location encoding (unchanged from v1 minter).
     * @dev Layout: `version (1) | type (1) | chainId (32) | recordsContract (20) | slot (32)` = 86 bytes.
     *      The 32-byte `chainId` field must equal `block.chainid` so locations minted for another network
     *      are rejected here instead of being stored and mistaken for a local list.
     * @param listStorageLocation Full location blob from the user.
     * @return slot List slot on the records contract identified in the blob.
     * @return recordsContract Address of the list records contract embedded in the blob.
     */
    function decodeL1ListStorageLocation(bytes calldata listStorageLocation)
        public
        view
        returns (uint256 slot, address recordsContract)
    {
        require(
            listStorageLocation.length == 1 + 1 + 32 + 20 + 32, "EFPListEntryV2: invalid list storage location length"
        );
        require(listStorageLocation[0] == 0x01, "EFPListEntryV2: invalid list storage location version");
        require(listStorageLocation[1] == 0x01, "EFPListEntryV2: invalid list storage location type");
        uint256 encodedChainId = uint256(bytes32(listStorageLocation[2:34]));
        require(encodedChainId == block.chainid, "EFPListEntryV2: chain id mismatch");
        recordsContract = address(uint160(bytes20(listStorageLocation[34:54])));
        slot = uint256(bytes32(listStorageLocation[54:86]));
    }

    /**
     * @notice Registers a list for `msg.sender`, sets their `primary-list`, and wires L1 records if applicable.
     * @param listStorageLocation L1-encoded location (see {decodeL1ListStorageLocation}).
     */
    function bootstrapList(bytes calldata listStorageLocation) external payable whenNotPaused {
        (uint256 slot, address recordsContract) = decodeL1ListStorageLocation(listStorageLocation);
        uint256 listId = registry.totalLists();
        registry.mintTo{value: msg.value}(msg.sender, listStorageLocation);
        _setDefaultListForAccount(msg.sender, listId);
        if (recordsContract == address(listRecordsL1)) {
            listRecordsL1.setListUser(slot, msg.sender);
            listRecordsL1.setListManager(slot, msg.sender);
        }
    }

    /**
     * @notice Like {bootstrapList}, but the new list owner is `to`. `primary-list` is still set for `msg.sender`
     *         (same quirk as v1 `easyMintTo`).
     * @param to Address that will own the new list id in the registry.
     * @param listStorageLocation L1-encoded location (see {decodeL1ListStorageLocation}).
     */
    function bootstrapListTo(address to, bytes calldata listStorageLocation) external payable whenNotPaused {
        (uint256 slot, address recordsContract) = decodeL1ListStorageLocation(listStorageLocation);
        uint256 listId = registry.totalLists();
        registry.mintTo{value: msg.value}(to, listStorageLocation);
        _setDefaultListForAccount(msg.sender, listId);
        if (recordsContract == address(listRecordsL1)) {
            listRecordsL1.setListUser(slot, msg.sender);
            listRecordsL1.setListManager(slot, msg.sender);
        }
    }

    /// @dev Writes `primary-list` as raw `abi.encodePacked(listId)` for indexer/client parity with v1.
    function _setDefaultListForAccount(address to, uint256 listId) internal {
        accountMetadata.setValueForAddress(to, "primary-list", abi.encodePacked(listId));
    }
}
