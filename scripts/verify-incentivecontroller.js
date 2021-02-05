module.exports = [
  '0x6ee5486e6cd36959be533921217a6dad1d3d7673', // pair address
  '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // target token (UNI)
  '0x1f9840a85d5af5bf1d1762f925bdaddc4201f984', // incentive token (UNI)
  true, // _isTokenAProtocolToken,
  100000, // rewardPerHour
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0x2D7cF3F8A86d2Db82198A907C6d0Ae5DC1810781 --network goerli
