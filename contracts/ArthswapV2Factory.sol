// SPDX-License-Identifier: MIT

pragma solidity =0.5.16;

import '@openzeppelin/contracts/access/Ownable.sol';

import './interfaces/ICustomERC20.sol';
import '../interfaces/ISimpleOracle.sol';
import '../interfaces/IUniswapOracle.sol';
import './interfaces/IUniswapV2Factory.sol';
import './UniswapV2Pair.sol';

contract ArthswapV2Factory is IUniswapV2Factory, Ownable {
    /**
     * State variables.
     */

    address public feeTo;
    // Who can set the feeTo.
    address public feeToSetter;

    // Token which will charge penalty.
    ICustomERC20 public penaltyToken;
    // Token which will be used for rewards.
    ICustomERC20 public rewardToken;

    // Token addresses for custom pools.
    address daiTokenAddress = address(0x6b175474e89094c44da98b954eedeac495271d0f);
    address arthTokenAddress = address(0x0E3cC2c4FB9252d17d07C67135E48536071735D9);

    // Token which will be used for  to track the latest target price.
    ISimpleOracle gmuOracle;
    // Used to track the latest twap price.
    IUniswapOracle uniswapOracle;

    address[] public allPairs;
    mapping(address => mapping(address => address)) public getPair;

    /**
     * Event.
     */
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256);

    /**
     * Constructor.
     */
    constructor(
        address _feeToSetter,
        address _penaltyToken,
        address _rewardToken,
        address _gmuOracle,
        address _uniswapOracle
    ) public {
        feeToSetter = _feeToSetter;

        rewardToken = ICustomERC20(_rewardToken);
        penaltyToken = ICustomERC20(_penaltyToken);

        gmuOracle = ISimpleOracle(_gmuOracle);
        uniswapOracle = IUniswapOracle(_uniswapOracle);
    }

    /**
     * Setters.
     */

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter || msg.sender == owner(), 'UniswapV2: FORBIDDEN');

        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter || msg.sender == owner(), 'UniswapV2: FORBIDDEN');

        feeToSetter = _feeToSetter;
    }

    function setGmuOracle(address newGmuOracle) public onlyOwner {
        require(newGmuOracle != address(0), 'Pair: invalid oracle');

        gmuOracle = ISimpleOracle(newGmuOracle);
    }

    function setUniswapOracle(address newUniswapOracle) public onlyOwner {
        require(newUniswapOracle != address(0), 'Pair: invalid oracle');

        uniswapOracle = IUniswapOracle(newUniswapOracle);
    }

    function setPenaltyToken(address newPenaltyToken) public onlyOwner {
        require(newUniswapOracle != address(0), 'Pair: invalid token');

        penaltyToken = ICustomERC20(newPenaltyToken);
    }

    function setRewardToken(address newRewardToken) public onlyOwner {
        require(newRewardToken != address(0), 'Pair: invalid token');

        rewardToken = ICustomERC20(newRewardToken);
    }

    /**
     * Getter.
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * Mutations.
     */

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'UniswapV2: IDENTICAL_ADDRESSES');

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);

        require(token0 != address(0), 'UniswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'UniswapV2: PAIR_EXISTS'); // single check is sufficient

        bytes memory bytecode = type(UniswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));

        // TODO: recheck this byte code implementation.
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IUniswapV2Pair(pair).initialize(
            token0,
            token1,
            address(penaltyToken),
            address(rewardToken),
            address(gmuOracle),
            address(uniswapOracle)
        );

        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }
}
