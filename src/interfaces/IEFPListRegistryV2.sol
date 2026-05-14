// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IEFPListRegistryV2
 * @author Ethereum Follow Protocol (v2 shape in this repository)
 * @notice Assigns monotonic numeric list IDs, binds each to an owner and an opaque `listStorageLocation` blob.
 *
 * @dev This is intentionally **not** an ERC-721: there is no transferable token surface, only explicit
 *      per-list ownership and storage metadata. The word “mint” is kept for familiarity with v1
 *      [`IEFPListRegistry`](https://github.com/ethereumfollowprotocol/contracts) but here it only means
 *      “allocate the next list id”.
 *
 *      **Why `MintState` exists without NFTs:** it controls **who may register a new list** (allocate
 *      a new id), which is independent of NFTs. Typical uses: keep registration closed during deploy,
 *      restrict list creation to the protocol admin for a private beta, then open public registration.
 *      It is the same *policy knob* v1 used, minus batch/NFT-specific modes.
 */
interface IEFPListRegistryV2 {
  /**
   * @notice Policy for creating new lists (allocating new ids).
   * @dev Naming mirrors historical “mint” wording; no ERC-721 mint occurs.
   * @param Disabled No one may create lists until the owner selects another mode.
   * @param OwnerOnly Only the contract `owner` may create lists.
   * @param PublicMint Any address may create lists, subject to `mintPrice` and pause.
   */
  enum MintState {
    Disabled,
    OwnerOnly,
    PublicMint
  }

  /// @notice Emitted whenever a list’s storage location bytes change (including at creation).
  event UpdateListStorageLocation(uint256 indexed listId, bytes listStorageLocation);

  /// @return The opaque EFP list storage location for `listId` (may be empty if unset in edge cases).
  function getListStorageLocation(uint256 listId) external view returns (bytes memory);

  /// @notice Updates storage location for a list; must be called by that list’s owner.
  function setListStorageLocation(uint256 listId, bytes calldata listStorageLocation) external;

  /// @return Address that controls updates to `listId`’s storage location (not an NFT ownerOf).
  function getListOwner(uint256 listId) external view returns (address);

  /// @return Number of lists ever created (also the next id to assign).
  function totalLists() external view returns (uint256);

  /// @return Current registration policy (see {MintState}).
  function getMintState() external view returns (MintState);

  /// @notice Sets who may create new lists. Callable only by the contract owner.
  function setMintState(MintState newMintState) external;

  /// @return Wei required per new list (in addition to any wrapper contract fees).
  function mintPrice() external view returns (uint256);

  /// @notice Updates the wei toll for creating a list. Callable only by the contract owner.
  function setMintPrice(uint256 newMintPrice) external;

  /// @notice Creates a list for `msg.sender` with the given storage location.
  function mint(bytes calldata listStorageLocation) external payable;

  /// @notice Creates a list for `recipient` with the given storage location.
  function mintTo(address recipient, bytes calldata listStorageLocation) external payable;
}
