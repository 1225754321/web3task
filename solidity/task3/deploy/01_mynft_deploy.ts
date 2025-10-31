import { ethers, upgrades } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { writeCfg } from "../utils/config"

module.exports = async ({
}: HardhatRuntimeEnvironment) => {

    // 获取合约工厂
    const MyNFTFy = await ethers.getContractFactory("MyNFT");
    // 通过代理部署合约
    const myNFTProxy = await upgrades.deployProxy(MyNFTFy, ["TestNFT", "SH_NFT"], {
        initializer: "initialize",
    });
    // 等待部署完成
    await myNFTProxy.waitForDeployment();

    const proxyAddress = await myNFTProxy.getAddress();
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        proxyAddress
    );

    await writeCfg("MyNFTProxy", {
        abi: MyNFTFy.interface.format(true),
        address: proxyAddress,
        implementation: implementationAddress,
        args: ["TestNFT", "SH_NFT"],
    });
};

module.exports.tags = ["mynft_deploy"];
