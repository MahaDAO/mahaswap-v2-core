// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ICustomERC20 is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}
