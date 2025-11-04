import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { writeCfg } from "../utils/utils"

module.exports = async ({
}: HardhatRuntimeEnvironment) => {

    // 获取合约工厂
    const NFTAuctionFactoryFy = await ethers.getContractFactory("NFTAuctionFactory");
    // 通过代理部署合约
    // NFTAuctionFactory 的 initialize() 没有参数
    const nftAuctionFactoryProxy = await upgrades.deployProxy(NFTAuctionFactoryFy, [], {
        initializer: "__NFTAuctionFactory_init",
    });
    // 等待部署完成
    await nftAuctionFactoryProxy.waitForDeployment();

    const proxyAddress = await nftAuctionFactoryProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("NFTAuctionFactoryProxy", {
        abi: NFTAuctionFactoryFy.interface.format(true),
        address: proxyAddress,
        implementation: implementationAddress,
        args: [], // initialize() 没有参数
    });
};

module.exports.tags = ["nftauctionfactory_deploy"];