// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface ISimpleOracle {
    function getPrice() external view returns (uint256 amountOut);
}
