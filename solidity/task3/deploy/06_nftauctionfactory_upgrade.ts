import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readCfg, writeCfg } from "../utils/utils"

module.exports = async ({ }: HardhatRuntimeEnvironment) => {

    const nftAuctionFactoryProxyCfg = await readCfg("NFTAuctionFactoryProxy");

    // 获取合约工厂
    const NFTAuctionFactoryV2Fy = await ethers.getContractFactory("NFTAuctionFactoryV2");
    // 升级代理合约
    const nftAuctionFactoryProxy = await upgrades.upgradeProxy(nftAuctionFactoryProxyCfg.address, NFTAuctionFactoryV2Fy);
    await nftAuctionFactoryProxy.waitForDeployment();

    const proxyAddress = await nftAuctionFactoryProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("NFTAuctionFactoryProxy", {
        abi: NFTAuctionFactoryV2Fy.interface.format(true),
        address: proxyAddress,
        implementation2: implementationAddress,
        ...nftAuctionFactoryProxyCfg,
    });
};

module.exports.tags = ["nftauctionfactory_upgrade"];