// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract GoldAMM is ERC20, ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    error ZeroAddress();
    error ZeroAmount();
    error InsufficientLiquidity();
    error SlippageExceeded();
    error IdenticalTokens();
    error InsufficientShares();
    error InvalidToken();

    event LiquidityAdded(
        address indexed provider, uint256 amount0, uint256 amount1, uint256 shares
    );
    event LiquidityRemoved(
        address indexed provider, uint256 amount0, uint256 amount1, uint256 shares
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    constructor(address _token0, address _token1, address owner_)
        ERC20("GoldAMM LP", "GVLP")
        Ownable(owner_)
    {
        if (_token0 == address(0) || _token1 == address(0) || owner_ == address(0)) revert ZeroAddress();
        if (_token0 == _token1) revert IdenticalTokens();
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    )
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1, uint256 shares)
    {
        if (amount0Desired == 0 || amount1Desired == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        uint256 supply = totalSupply();

        if (supply == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
            shares = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0xdead), MINIMUM_LIQUIDITY);
        } else {
            uint256 amount1Optimal = (amount0Desired * _reserve1) / _reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert SlippageExceeded();
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = (amount1Desired * _reserve0) / _reserve1;
                if (amount0Optimal < amount0Min) revert SlippageExceeded();
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
            shares = Math.min((amount0 * supply) / _reserve0, (amount1 * supply) / _reserve1);
        }

        if (shares == 0) revert InsufficientShares();
        if (amount0 < amount0Min) revert SlippageExceeded();
        if (amount1 < amount1Min) revert SlippageExceeded();

        reserve0 = _reserve0 + amount0;
        reserve1 = _reserve1 + amount1;

        _mint(to, shares);
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        emit LiquidityAdded(msg.sender, amount0, amount1, shares);
    }

    function removeLiquidity(uint256 shares, uint256 amount0Min, uint256 amount1Min, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        if (shares == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        uint256 supply = totalSupply();
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        amount0 = (shares * _reserve0) / supply;
        amount1 = (shares * _reserve1) / supply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();
        if (amount0 < amount0Min) revert SlippageExceeded();
        if (amount1 < amount1Min) revert SlippageExceeded();

        reserve0 = _reserve0 - amount0;
        reserve1 = _reserve1 - amount1;

        _burn(msg.sender, shares);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);

        emit LiquidityRemoved(msg.sender, amount0, amount1, shares);
    }

    function swapExactToken0ForToken1(uint256 amountIn, uint256 amountOutMin, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        if (_reserve0 == 0 || _reserve1 == 0) revert InsufficientLiquidity();

        amountOut = _getAmountOut(amountIn, _reserve0, _reserve1);
        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (amountOut >= _reserve1) revert InsufficientLiquidity();

        reserve0 = _reserve0 + amountIn;
        reserve1 = _reserve1 - amountOut;

        token0.safeTransferFrom(msg.sender, address(this), amountIn);
        token1.safeTransfer(to, amountOut);

        emit Swap(msg.sender, address(token0), amountIn, amountOut, to);
    }

    function swapExactToken1ForToken0(uint256 amountIn, uint256 amountOutMin, address to)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (to == address(0)) revert ZeroAddress();

        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        if (_reserve0 == 0 || _reserve1 == 0) revert InsufficientLiquidity();

        amountOut = _getAmountOut(amountIn, _reserve1, _reserve0);
        if (amountOut < amountOutMin) revert SlippageExceeded();
        if (amountOut >= _reserve0) revert InsufficientLiquidity();

        reserve1 = _reserve1 + amountIn;
        reserve0 = _reserve0 - amountOut;

        token1.safeTransferFrom(msg.sender, address(this), amountIn);
        token0.safeTransfer(to, amountOut);

        emit Swap(msg.sender, address(token1), amountIn, amountOut, to);
    }

    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;

        if (tokenIn == address(token0)) {
            return _getAmountOut(amountIn, _reserve0, _reserve1);
        }

        if (tokenIn == address(token1)) {
            return _getAmountOut(amountIn, _reserve1, _reserve0);
        }

        revert InvalidToken();
    }

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        internal
        pure
        returns (uint256)
    {
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        if (amountIn == 0) revert ZeroAmount();
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        return numerator / denominator;
    }
}
