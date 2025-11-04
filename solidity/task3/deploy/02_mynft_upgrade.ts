import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readCfg, writeCfg } from "../utils/utils"

module.exports = async ({ }: HardhatRuntimeEnvironment) => {

    const myNFTProxyCfg = await readCfg("MyNFTProxy");

    // 获取合约工厂
    const MyNftV2Fy = await ethers.getContractFactory("MyNftV2");
    // 升级代理合约
    const myNFTProxy = await upgrades.upgradeProxy(myNFTProxyCfg.address, MyNftV2Fy);
    await myNFTProxy.waitForDeployment();

    const proxyAddress = await myNFTProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("MyNFTProxy", {
        abi: MyNftV2Fy.interface.format(true),
        address: proxyAddress,
        implementation: implementationAddress,
    });
};

module.exports.tags = ["mynft_upgrade"];
