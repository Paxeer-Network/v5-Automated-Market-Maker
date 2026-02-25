// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;

import "../tokens/ERC721Permit.sol";
import "../core/interfaces/ILiquidityFacet.sol";
import "../core/interfaces/IERC20.sol";
import "../utils/SafeTransfer.sol";
import "../utils/ReentrancyGuard.sol";

/// @title PositionManager — ERC-721 NFT-based LP position management
/// @notice Wraps Diamond liquidity operations with NFT position tracking
/// @dev Stateless periphery contract — no external dependencies
contract PositionManager is ERC721Permit, ReentrancyGuard {
    using SafeTransfer for address;

    address public immutable diamond;
    address public positionDescriptor;

    uint256 private _nextTokenId = 1;

    // tokenId => Diamond positionId
    mapping(uint256 => uint256) public tokenToPositionId;
    // Diamond positionId => tokenId
    mapping(uint256 => uint256) public positionIdToToken;

    struct MintParams {
        bytes32 poolId;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct CollectParams {
        uint256 tokenId;
        address recipient;
    }

    event PositionMinted(uint256 indexed tokenId, uint256 indexed positionId, address indexed owner);
    event PositionBurned(uint256 indexed tokenId);

    error NotApprovedOrOwner();
    error PositionNotEmpty();
    error DeadlineExpired();

    constructor(address _diamond, address _positionDescriptor)
        ERC721Permit("v5-ASAMM Position", "v5-ASAMM-POS")
    {
        diamond = _diamond;
        positionDescriptor = _positionDescriptor;
    }

    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        _;
    }

    modifier isAuthorized(uint256 tokenId) {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
        _;
    }

    /// @notice Mint a new position NFT by adding liquidity
    /// @param params The mint parameters
    /// @return tokenId The NFT token ID
    /// @return positionId The Diamond position ID
    /// @return liquidity The liquidity minted
    /// @return amount0 Token0 deposited
    /// @return amount1 Token1 deposited
    function mint(MintParams calldata params)
        external
        nonReentrant
        checkDeadline(params.deadline)
        returns (uint256 tokenId, uint256 positionId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // Add liquidity via Diamond
        ILiquidityFacet.AddLiquidityParams memory addParams = ILiquidityFacet.AddLiquidityParams({
            poolId: params.poolId,
            tickLower: params.tickLower,
            tickUpper: params.tickUpper,
            amount0Desired: params.amount0Desired,
            amount1Desired: params.amount1Desired,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            recipient: address(this), // Diamond tracks this contract as position owner
            deadline: params.deadline
        });

        (positionId, liquidity, amount0, amount1) = ILiquidityFacet(diamond).addLiquidity(addParams);

        // Mint NFT
        tokenId = _nextTokenId++;
        _safeMint(params.recipient, tokenId);

        // Link NFT to Diamond position
        tokenToPositionId[tokenId] = positionId;
        positionIdToToken[positionId] = tokenId;

        emit PositionMinted(tokenId, positionId, params.recipient);
    }

    /// @notice Decrease liquidity of an existing position
    /// @param params The decrease parameters
    /// @return amount0 Token0 withdrawn
    /// @return amount1 Token1 withdrawn
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        nonReentrant
        isAuthorized(params.tokenId)
        checkDeadline(params.deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 positionId = tokenToPositionId[params.tokenId];
        ILiquidityFacet.Position memory pos = ILiquidityFacet(diamond).getPosition(positionId);

        ILiquidityFacet.RemoveLiquidityParams memory removeParams = ILiquidityFacet.RemoveLiquidityParams({
            poolId: pos.poolId,
            positionId: positionId,
            liquidityAmount: params.liquidity,
            amount0Min: params.amount0Min,
            amount1Min: params.amount1Min,
            recipient: ownerOf(params.tokenId),
            deadline: params.deadline
        });

        (amount0, amount1) = ILiquidityFacet(diamond).removeLiquidity(removeParams);
    }

    /// @notice Collect fees from a position
    /// @param params The collect parameters
    /// @return amount0 Token0 fees collected
    /// @return amount1 Token1 fees collected
    function collect(CollectParams calldata params)
        external
        nonReentrant
        isAuthorized(params.tokenId)
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 positionId = tokenToPositionId[params.tokenId];
        ILiquidityFacet.Position memory pos = ILiquidityFacet(diamond).getPosition(positionId);

        (amount0, amount1) = ILiquidityFacet(diamond).collectFees(
            pos.poolId,
            positionId,
            params.recipient
        );
    }

    /// @notice Burn a position NFT (only if liquidity is zero)
    /// @param tokenId The token to burn
    function burn(uint256 tokenId) external isAuthorized(tokenId) {
        uint256 positionId = tokenToPositionId[tokenId];
        ILiquidityFacet.Position memory pos = ILiquidityFacet(diamond).getPosition(positionId);

        if (pos.liquidity > 0) revert PositionNotEmpty();

        _burn(tokenId);
        delete tokenToPositionId[tokenId];
        delete positionIdToToken[positionId];

        emit PositionBurned(tokenId);
    }

    /// @notice Get the URI for a position NFT
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "PositionManager: nonexistent token");
        if (positionDescriptor != address(0)) {
            return IPositionDescriptor(positionDescriptor).tokenURI(address(this), tokenId);
        }
        return "";
    }

    /// @notice Set the position descriptor address
    function setPositionDescriptor(address _descriptor) external {
        // In production, this should be owner-gated
        positionDescriptor = _descriptor;
    }
}

interface IPositionDescriptor {
    function tokenURI(address positionManager, uint256 tokenId) external view returns (string memory);
}
