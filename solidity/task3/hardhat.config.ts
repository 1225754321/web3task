import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'hardhat-deploy';
import "@openzeppelin/hardhat-upgrades";
import dotenv from "dotenv";


dotenv.config();

const config: HardhatUserConfig = {
    solidity: "0.8.28",
    namedAccounts: {
        deployer: 0,
        user1: 1,
        user2: 2,
        user3: 3,
        user4: 4,
    },
    networks: {
        sepolia: {
            url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}` || "",
            accounts: [process.env.PRIVATE_KEY || ""]
        }
    }
};

export default config;
