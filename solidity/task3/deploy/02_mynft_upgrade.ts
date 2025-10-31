import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readCfg, writeCfg } from "../utils/config"

module.exports = async ({ }: HardhatRuntimeEnvironment) => {

    const myNFTProxyCfg = await readCfg("MyNFTProxy");

    // 获取合约工厂
    const MyNFT_V2Fy = await ethers.getContractFactory("MyNFT_V2");
    // 升级代理合约
    const myNFTProxy = await upgrades.upgradeProxy(myNFTProxyCfg.address, MyNFT_V2Fy);
    await myNFTProxy.waitForDeployment();

    const proxyAddress = await myNFTProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("MyNFTProxy", {
        abi: MyNFT_V2Fy.interface.format(true),
        address: proxyAddress,
        implementation: implementationAddress,
    });
};

module.exports.tags = ["mynft_upgrade"];
