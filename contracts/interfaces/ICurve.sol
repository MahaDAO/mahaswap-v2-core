// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

interface ICurve {
    function getCurvedDeviation(uint256 deviation) external view returns (uint256);
}
