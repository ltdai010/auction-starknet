import 'hardhat-deploy';
import "@nomiclabs/hardhat-etherscan";
import "hardhat-prettier";
import '@nomiclabs/hardhat-ethers';

import { HardhatUserConfig } from 'hardhat/types';

interface ExtendedHardhatUserConfig extends HardhatUserConfig {
  namedAccounts: { [key: string]: string };
}
const ehhuc: ExtendedHardhatUserConfig = {
  solidity: "0.8.10",
  networks: {
    goerli: {
      url: 'https://eth-goerli.alchemyapi.io/v2/16G9jPrssFNtAgVdicQC325mIe3MdNvs',
      accounts: {
        mnemonic: 'glare chunk hat pencil theme proof live outer wrong tennis fabric long'
      }
    }
  },
  namedAccounts: {
    deployer: '0xD090bF0279391390797b6d66E02598B7aD59d089'
  },
  etherscan: {
    apiKey: "MC4HZZFTSEKVRMIER899NBNSAWSEUK3RX3"
  }
};

export default ehhuc;
