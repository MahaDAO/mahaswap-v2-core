module.exports = [
  '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
  '0x7e53072c6ca9104c60362586d9080a22ea366e91', // target token (ARTH)
  '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (NAHA)
  "250000000000000000000", // rewardPerHour
  "87000000000000000" // ARTH to MAHA price
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0x3E617c60C093881ef221BCA1216266f14B60604c --network goerli
// 10000003099989911203319/10000008908138970689300