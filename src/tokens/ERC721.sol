// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/IERC165.sol";

/// @title ERC721 — Minimal custom ERC-721 implementation
/// @notice Custom implementation — no external dependencies
contract ERC721 is IERC165 {
    string public name;
    string public symbol;

    mapping(uint256 => address) internal _ownerOf;
    mapping(address => uint256) internal _balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    error ERC721_NotOwnerOrApproved();
    error ERC721_InvalidRecipient();
    error ERC721_TokenDoesNotExist();
    error ERC721_AlreadyMinted();
    error ERC721_TransferToNonReceiver();

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address owner_) {
        owner_ = _ownerOf[tokenId];
        if (owner_ == address(0)) revert ERC721_TokenDoesNotExist();
    }

    function balanceOf(address owner_) public view virtual returns (uint256) {
        require(owner_ != address(0), "ERC721: zero address");
        return _balanceOf[owner_];
    }

    function approve(address to, uint256 tokenId) public virtual {
        address owner_ = _ownerOf[tokenId];
        if (msg.sender != owner_ && !isApprovedForAll[owner_][msg.sender]) {
            revert ERC721_NotOwnerOrApproved();
        }
        getApproved[tokenId] = to;
        emit Approval(owner_, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) revert ERC721_InvalidRecipient();

        address owner_ = _ownerOf[tokenId];
        if (from != owner_) revert ERC721_NotOwnerOrApproved();
        if (msg.sender != owner_ && !isApprovedForAll[owner_][msg.sender] && msg.sender != getApproved[tokenId]) {
            revert ERC721_NotOwnerOrApproved();
        }

        unchecked {
            _balanceOf[from]--;
            _balanceOf[to]++;
        }

        _ownerOf[tokenId] = to;
        delete getApproved[tokenId];

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);

        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721_TransferToNonReceiver();
                }
            } catch {
                revert ERC721_TransferToNonReceiver();
            }
        }
    }

    function tokenURI(uint256) public view virtual returns (string memory) {
        return "";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == 0x01ffc9a7 || // ERC165
            interfaceId == 0x80ac58cd || // ERC721
            interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    // --- Internal ---

    function _mint(address to, uint256 tokenId) internal virtual {
        if (to == address(0)) revert ERC721_InvalidRecipient();
        if (_ownerOf[tokenId] != address(0)) revert ERC721_AlreadyMinted();

        unchecked {
            _balanceOf[to]++;
        }

        _ownerOf[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual {
        address owner_ = _ownerOf[tokenId];
        if (owner_ == address(0)) revert ERC721_TokenDoesNotExist();

        unchecked {
            _balanceOf[owner_]--;
        }

        delete _ownerOf[tokenId];
        delete getApproved[tokenId];

        emit Transfer(owner_, address(0), tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal virtual {
        _mint(to, tokenId);
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, address(0), tokenId, "") returns (bytes4 retval) {
                if (retval != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721_TransferToNonReceiver();
                }
            } catch {
                revert ERC721_TransferToNonReceiver();
            }
        }
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner_ = ownerOf(tokenId);
        return (spender == owner_ || isApprovedForAll[owner_][spender] || getApproved[tokenId] == spender);
    }
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}
