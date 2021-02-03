// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

interface ISimpleOracle {
    function getPrice() external view returns (uint256 amountOut);
}
