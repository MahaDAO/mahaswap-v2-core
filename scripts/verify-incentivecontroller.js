module.exports = [
  '0x1C36D9E60cac6893652b74E357f3829A0f5095e0', // pair address
  '0x0e3cc2c4fb9252d17d07c67135e48536071735d9', // target token (ARTH)
  '0x5aC2A32BFa475765558CEa2A0Fe0bF0207D58Ca4', // ecosystem fund
  '0xb4d930279552397bba2ee473229f89ec245bc365', // incentive token (NAHA)
  "500000000000000000000", // rewardPerEpoch
  "66666666670000000", // ARTH to MAHA price
  12 * 60 * 60 // period
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0xf4Ae41C9966668fad03F5BFc0c4D7e7239F86e94 --network ropsten
// 10000003099989911203319/10000008908138970689300
