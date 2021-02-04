// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

interface IIncentiveController {
    function conductChecks(
        address tokenA,
        address tokenB,
        uint112 reserveA,
        uint112 reserveB,
        uint112 newReserveA,
        uint112 newReserveB,
        address from,
        address to,
        uint256 amountOutA,
        uint256 amountOutB
    ) external;
}
