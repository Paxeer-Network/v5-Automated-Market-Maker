// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "./ERC721.sol";

/// @title ERC721Permit — ERC-721 with EIP-4494 permit support
/// @notice Allows gasless approvals for NFT transfers
/// @dev Custom implementation — no external dependencies
abstract contract ERC721Permit is ERC721 {
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;

    mapping(uint256 => uint256) public permitNonces;

    error ERC721Permit_Expired();
    error ERC721Permit_InvalidSignature();

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        _HASHED_NAME = keccak256(bytes(_name));
        _HASHED_VERSION = keccak256("1");
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    /// @notice Approve a spender for a token via signature
    /// @param spender The address to approve
    /// @param tokenId The token to approve
    /// @param deadline The deadline for the signature
    /// @param v The v component of the signature
    /// @param r The r component of the signature
    /// @param s The s component of the signature
    function permit(
        address spender,
        uint256 tokenId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        if (block.timestamp > deadline) revert ERC721Permit_Expired();

        address owner_ = ownerOf(tokenId);

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, spender, tokenId, permitNonces[tokenId]++, deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0) || (signer != owner_ && !isApprovedForAll[owner_][signer])) {
            revert ERC721Permit_InvalidSignature();
        }

        getApproved[tokenId] = spender;
        emit Approval(owner_, spender, tokenId);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID ? _CACHED_DOMAIN_SEPARATOR : _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
    }
}
