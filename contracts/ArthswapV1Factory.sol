// SPDX-License-Identifier: MIT

pragma solidity ^0.7.4;

import '@openzeppelin/contracts/access/Ownable.sol';

import './UniswapV2Pair.sol';
import './ArthswapV1Pair.sol';
import './interfaces/ICustomERC20.sol';
import './interfaces/ISimpleOracle.sol';
import './interfaces/IUniswapOracle.sol';
import './interfaces/IUniswapV2Factory.sol';
import './interfaces/IArthswapV1Factory.sol';

contract ArthswapV1Factory is IArthswapV1Factory, Ownable {
    /**
     * State variables.
     */

    address public feeTo;
    // Who can set the feeTo.
    address public feeToSetter;

    // Default uniswap factory for pairs that aren't created arthswap.
    IUniswapV2Factory defaultFactory;

    // Pair management.
    address[] public allPairs;
    mapping(address => mapping(address => address)) public pairs;

    /**
     * Event.
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    /**
     * Constructor.
     */
    constructor(address _defaultFactory, address _feeToSetter) public {
        feeToSetter = _feeToSetter;

        defaultFactory = IUniswapV2Factory(_defaultFactory);
    }

    /**
     * Getters.
     */

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function getPair(address token0, address token1) public returns (address) {
        if (pairs[token0][token1] == address(0)) {
            return defaultFactory.getPair[token][token1];
        }

        return pairs[token0][token1];
    }

    /**
     * Mutations.
     */

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'ArthswapV1: IDENTICAL_ADDRESSES');

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), 'ArthswapV1: ZERO_ADDRESS');
        // A single check is sufficient.
        require(pairs[token0][token1] == address(0), 'ArthswapV1: PAIR_EXISTS');

        // NOTE: shouln't this be created on for ArthswapV1Pair?
        // bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes memory bytecode = type(ArthswapV1Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        // IUniswapV2Pair(pair).initialize(token0, token1);
        IArthswapV1Pair(pair).initialize(token0, token1);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair; // Also populate mapping in the reverse direction.
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter || msg.sender == owner(), 'ArthswapV1: FORBIDDEN');

        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter || msg.sender == owner(), 'ArthswapV1: FORBIDDEN');

        feeToSetter = _feeToSetter;
    }

    function setIncentiveControllerForPair(
        address token0,
        address token1,
        address controller
    ) public onlyOwner {
        address pair = pairs[token0][token1];

        require(address(pair) != address(0), 'ArthswapV1: invalid pair');

        IArthswapV1Pair(pair).setIncentiveController(controller);
    }

    function setSwapingPausedForPair(
        address token0,
        address token1,
        bool isSet
    ) public onlyOwner {
        address pair = pairs[token0][token1];

        require(address(pair) != address(0), 'ArthswapV1: invalid pair');

        IArthswapV1Pair(pair).setSwapingPaused(isSet);
    }

    function setUseOracleForPair(
        address token0,
        address token1,
        bool isSet
    ) public onlyOwner {
        address pair = pairs[token0][token1];

        require(address(pair) != address(0), 'ArthswapV1: invalid pair');

        IArthswapV1Pair(pair).setUseOracle(isSet);
    }
}
