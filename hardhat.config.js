require("@nomiclabs/hardhat-ethers");
require("dotenv").config(); // load environment variables from .env file

const INFURA_API_KEY = process.env.INFURA_API_KEY;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
