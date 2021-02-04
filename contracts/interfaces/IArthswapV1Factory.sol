// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import './IUniswapV2Factory.sol';

interface IArthswapV1Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function defaultFactory() external view returns (IUniswapV2Factory);

    function pairs(address tokenA, address tokenB) external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function setIncentiveControllerForPair(
        address token0,
        address token1,
        address controller
    ) external;

    function setSwapingPausedForPair(
        address token0,
        address token1,
        bool isSet
    ) external;

    function createPair(address tokenA, address tokenB) external returns (address pair);
}
