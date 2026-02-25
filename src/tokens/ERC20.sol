// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../core/interfaces/IERC20.sol";
import "../core/interfaces/IERC20Permit.sol";

/// @title ERC20 — Minimal custom ERC-20 implementation with EIP-2612 permit
/// @notice Custom implementation — no external dependencies
contract ERC20 is IERC20, IERC20Permit {
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // EIP-2612 permit state
    mapping(address => uint256) public nonces;

    // EIP-712 domain separator (cached at deployment)
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private constant _TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    error ERC20_InsufficientBalance();
    error ERC20_InsufficientAllowance();
    error ERC20_InvalidRecipient();
    error ERC20_InvalidApprover();
    error ERC20_PermitExpired();
    error ERC20_InvalidSigner();

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        _HASHED_NAME = keccak256(bytes(_name));
        _HASHED_VERSION = keccak256("1");
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator();
    }

    function transfer(address to, uint256 amount) external virtual returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external virtual returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external virtual returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function permit(
        address _owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual {
        if (block.timestamp > deadline) revert ERC20_PermitExpired();

        bytes32 structHash = keccak256(
            abi.encode(_PERMIT_TYPEHASH, _owner, spender, value, nonces[_owner]++, deadline)
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), structHash));

        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0) || signer != _owner) revert ERC20_InvalidSigner();

        _approve(_owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == _CACHED_CHAIN_ID ? _CACHED_DOMAIN_SEPARATOR : _buildDomainSeparator();
    }

    // --- Internal ---

    function _transfer(address from, address to, uint256 amount) internal virtual {
        if (to == address(0)) revert ERC20_InvalidRecipient();
        if (balanceOf[from] < amount) revert ERC20_InsufficientBalance();

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _approve(address _owner, address spender, uint256 amount) internal virtual {
        if (_owner == address(0)) revert ERC20_InvalidApprover();
        allowance[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }

    function _spendAllowance(address _owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance[_owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert ERC20_InsufficientAllowance();
            unchecked {
                allowance[_owner][spender] = currentAllowance - amount;
            }
        }
    }

    function _mint(address to, uint256 amount) internal virtual {
        if (to == address(0)) revert ERC20_InvalidRecipient();
        totalSupply += amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        if (balanceOf[from] < amount) revert ERC20_InsufficientBalance();
        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION, block.chainid, address(this)));
    }
}
