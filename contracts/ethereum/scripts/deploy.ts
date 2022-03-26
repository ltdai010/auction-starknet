import {ethers} from 'hardhat';

async function main() {
  const GatewayERC20 = await ethers.getContractFactory('GatewayERC20');
  const gatewayERC20 = await GatewayERC20.deploy("0xde29d060D45901Fb19ED6C6e959EB22d8626708e");

  await gatewayERC20.deployed();

  console.log('GatewayERC20 deployed to:', gatewayERC20.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
  