// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '../interfaces/IIncentiveController.sol';

contract MockPairForController {
    // calls our special reward controller
    function conductChecks(
        address controller,
        uint112 reserve0,
        uint112 reserve1,
        uint256 price0Last,
        uint256 price1Last,
        uint256 amount0Out,
        uint256 amount1Out,
        uint256 amount0In,
        uint256 amount1In,
        address from,
        address to
    ) public {
        if (address(controller) == address(0)) return;
        IIncentiveController(controller).conductChecks(
            reserve0,
            reserve1,
            price0Last,
            price1Last,
            amount0Out,
            amount1Out,
            amount0In,
            amount1In,
            from,
            to
        );
    }
}
