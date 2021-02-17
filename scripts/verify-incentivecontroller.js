module.exports = [
  '0x8c85541cc02e88242cb706f88f0724ea874dfb0e', // pair address
  '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // target token (ARTH)
  '0x5ac2a32bfa475765558cea2a0fe0bf0207d58ca4', // ecosystem fund
  '0xcd24efb0f7285cb923cab11a85fbdb1523f10011', // incentive token (NAHA)
  "500000000000000000000", // rewardPerEpoch
  "1000000000000000000", // ARTH to MAHA price
  5 * 60 // period
]
// npx hardhat verify --constructor-args scripts/verify-incentivecontroller.js 0x9A0b30b37E35b3aD02f63E62F38E755dacE276Dc --network ropsten
// 10000003099989911203319/10000008908138970689300
