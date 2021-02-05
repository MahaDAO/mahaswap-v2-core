module.exports = [
  '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
  '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // target token (ARTH)
  '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (NAHA)
  false, // _isTokenAProtocolToken,
  "13000000000000000000", // rewardPerHour
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0x1BAc25AaBb5398E94eA838Dc8B90b0eAF94edCe7 --network goerli
