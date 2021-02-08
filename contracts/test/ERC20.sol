// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '../MahaswapV1ERC20.sol';

contract ERC20 is MahaswapV1ERC20 {
    constructor(uint256 _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
