// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IIncentiveController {
    function conductChecks(
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external;
}
