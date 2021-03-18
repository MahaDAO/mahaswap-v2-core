module.exports = [
  '0xe207492fad13324b3b80b1a4324a203b61fc11a6', // pair address
  '0x0e3cc2c4fb9252d17d07c67135e48536071735d9', // target token (ARTH)
  '0x5aC2A32BFa475765558CEa2A0Fe0bF0207D58Ca4', // ecosystem fund
  '0xb4d930279552397bba2ee473229f89ec245bc365', // incentive token (NAHA)
  '500000000000000000000', // rewardPerEpoch
  '111111111100000000', // ARTH to MAHA price
  12 * 60 * 60, // period
  '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
]

// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0x83f5F39d7671D2d4443f1308E24e156cd078C662 --network mainnet
// 10000003099989911203319/10000008908138970689300
