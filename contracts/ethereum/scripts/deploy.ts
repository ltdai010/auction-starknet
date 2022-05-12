import {ethers} from 'hardhat';

async function main() {
  const Contract = await ethers.getContractFactory('GatewayERC721');
  const contract = await Contract.deploy('0xde29d060d45901fb19ed6c6e959eb22d8626708e');

  await contract.deployed();

  console.log('Contract deployed to:', contract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  