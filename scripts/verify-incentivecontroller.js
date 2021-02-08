module.exports = [
  '0x38eBdcB14674Ea32c982d7c93CcDf28F06a5c7a6', // pair address
  '0xfa1c36f01fea68726ec60cf1f050783aa9d1076c', // target token (ARTH)
  '0x981f0d72650583d4d6961def6c186d84d9e0f2b9', // incentive token (MAHA)
  "13000000000000000000", // rewardPerHour
  "87000000000000000" // ARTH to MAHA price
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0xD086f916533DBCD81cD52D5f072e7978Fdd87156 --network goerli
// 10000003099989911203319/10000008908138970689300