// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

interface IIncentiveController {
    function conductChecks(
        uint112 reserveA,
        uint112 reserveB,
        uint256 amountOutA,
        uint256 amountOutB,
        uint256 amountInA,
        uint256 amountInB,
        address to
    ) external;
}
