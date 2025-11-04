import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { readCfg, writeCfg } from "../utils/utils"

module.exports = async ({ }: HardhatRuntimeEnvironment) => {

    const nftAuctionProxyCfg = await readCfg("NFTAuctionProxy");

    // 获取合约工厂
    const NFTAuction_V2Fy = await ethers.getContractFactory("NFTAuctionV2");
    // 升级代理合约
    const nftAuctionProxy = await upgrades.upgradeProxy(nftAuctionProxyCfg.address, NFTAuction_V2Fy);
    await nftAuctionProxy.waitForDeployment();

    const proxyAddress = await nftAuctionProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("NFTAuctionProxy", {
        abi: NFTAuction_V2Fy.interface.format(true),
        address: proxyAddress,
        implementation2: implementationAddress,
        ...nftAuctionProxyCfg,
    });
};

module.exports.tags = ["nftauction_upgrade"];