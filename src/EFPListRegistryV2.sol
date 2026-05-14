// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEFPListRegistryV2} from "./interfaces/IEFPListRegistryV2.sol";

/**
 * @title EFPListRegistryV2
 * @notice Minimal on-chain registry: sequential list ids, explicit non-transferable list “ownership”,
 *         and a bytes payload per list describing where list data lives off-chain or on another contract.
 *
 * @dev Compared to v1 [`EFPListRegistry`](https://github.com/ethereumfollowprotocol/contracts):
 *      - No ERC-721 / ERC721A, no batch mint, no token URI or price oracle.
 *      - `MintState` only gates **registration** (who may create ids), not NFT behavior.
 *      - `Pausable` is an operational kill-switch; it is orthogonal to `MintState.Disabled`.
 *
 *      List ids start at `0` and increase by one, matching the historical “`totalSupply()` before mint”
 *      convention from the NFT-based registry so indexers and metadata encodings can stay aligned.
 */
contract EFPListRegistryV2 is IEFPListRegistryV2, Ownable, Pausable {
    /// @dev Current registration policy; see `IEFPListRegistryV2.MintState` in the interface NatSpec.
    MintState private mintState = MintState.Disabled;

    /// @dev Monotonic counter: equals number of lists created; the next assigned id is this value before increment.
    uint256 private _nextListId;

    /// @inheritdoc IEFPListRegistryV2
    uint256 public override mintPrice;

    mapping(uint256 listId => address) private _listOwner;

    mapping(uint256 listId => bytes) private _listStorageLocation;

    /// @param initialOwner Admin for Ownable-only functions (`setMintState`, `setMintPrice`, pause, withdraw).
    constructor(address initialOwner) Ownable(initialOwner) {}

    /// @notice Freezes mutating entrypoints that use `whenNotPaused`. Does not change `MintState`.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resumes normal operation after `pause`.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @inheritdoc IEFPListRegistryV2
    function setMintPrice(uint256 newMintPrice) external onlyOwner whenNotPaused {
        mintPrice = newMintPrice;
    }

    /**
     * @notice Sends native currency held by the registry to `recipient`.
     * @dev Callable only by the contract owner; typically collects `mintPrice` proceeds.
     */
    function withdraw(address payable recipient, uint256 amount) external onlyOwner returns (bool) {
        require(amount <= address(this).balance, "EFPListRegistryV2: insufficient balance");
        (bool sent,) = recipient.call{value: amount}("");
        require(sent, "EFPListRegistryV2: withdraw failed");
        return sent;
    }

    /// @inheritdoc IEFPListRegistryV2
    function getListStorageLocation(uint256 listId) external view override returns (bytes memory) {
        return _listStorageLocation[listId];
    }

    /// @inheritdoc IEFPListRegistryV2
    function getListOwner(uint256 listId) external view override returns (address) {
        return _listOwner[listId];
    }

    /// @inheritdoc IEFPListRegistryV2
    function totalLists() external view override returns (uint256) {
        return _nextListId;
    }

    /// @inheritdoc IEFPListRegistryV2
    function getMintState() external view override returns (MintState) {
        return mintState;
    }

    /// @inheritdoc IEFPListRegistryV2
    function setMintState(MintState newMintState) external override onlyOwner whenNotPaused {
        mintState = newMintState;
    }

    /// @inheritdoc IEFPListRegistryV2
    function setListStorageLocation(uint256 listId, bytes calldata listStorageLocation)
        external
        override
        whenNotPaused
    {
        require(_listOwner[listId] == msg.sender, "EFPListRegistryV2: not list owner");
        _setListStorageLocation(listId, listStorageLocation);
    }

    /// @inheritdoc IEFPListRegistryV2
    function mint(bytes calldata listStorageLocation) external payable override whenNotPaused mintAllowed {
        _mintTo(msg.sender, listStorageLocation);
    }

    /// @inheritdoc IEFPListRegistryV2
    function mintTo(address recipient, bytes calldata listStorageLocation)
        external
        payable
        override
        whenNotPaused
        mintAllowed
    {
        _mintTo(recipient, listStorageLocation);
    }

    /// @dev Enforces {MintState}: who may call `mint` / `mintTo` (allocate a new id).
    modifier mintAllowed() {
        require(mintState != MintState.Disabled, "EFPListRegistryV2: minting disabled");
        require(mintState != MintState.OwnerOnly || msg.sender == owner(), "EFPListRegistryV2: owner only");
        _;
    }

    /**
     * @dev Allocates `listId == _nextListId`, assigns `_listOwner[listId]`, stores location, increments counter.
     * @param recipient Address that will control `setListStorageLocation` for the new id.
     */
    function _mintTo(address recipient, bytes calldata listStorageLocation) internal {
        require(msg.value >= mintPrice, "EFPListRegistryV2: insufficient payment");
        uint256 listId = _nextListId;
        unchecked {
            _nextListId = listId + 1;
        }
        _listOwner[listId] = recipient;
        _setListStorageLocation(listId, listStorageLocation);
    }

    /// @dev Writes storage and emits {UpdateListStorageLocation}.
    function _setListStorageLocation(uint256 listId, bytes calldata listStorageLocation) internal {
        _listStorageLocation[listId] = listStorageLocation;
        emit UpdateListStorageLocation(listId, listStorageLocation);
    }
}
