import { deployments, ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readCfg, writeCfg } from "../utils/utils"

module.exports = async ({
}: HardhatRuntimeEnvironment) => {

    // 获取合约工厂
    const NFTAuctionFy = await ethers.getContractFactory("NFTAuction");

    // 获取前置mockusdc合约
    const mockusdcCfg = await readCfg("MockUSDC");

    // 通过代理部署合约
    // NFTAuction 的 initialize() 接受一个参数：USDC地址
    const nftAuctionProxy = await upgrades.deployProxy(NFTAuctionFy, [mockusdcCfg.address], {
        initializer: "__NFTAuction_init",
    });
    // 等待部署完成
    await nftAuctionProxy.waitForDeployment();

    const proxyAddress = await nftAuctionProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("NFTAuctionProxy", {
        abi: NFTAuctionFy.interface.format(true),
        address: proxyAddress,
        implementation: implementationAddress,
        args: [], // initialize() 没有参数
    });
};

module.exports.dependencies = ['mockusdc_deploy'];
module.exports.tags = ["nftauction_deploy"];