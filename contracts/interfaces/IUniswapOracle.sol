// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IUniswapOracle {
    function update() external;

    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut);
}
