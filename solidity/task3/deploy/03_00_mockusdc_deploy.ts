import { ethers } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { writeCfg } from "../utils/utils"

module.exports = async ({
}: HardhatRuntimeEnvironment) => {
    // 获取合约工厂
    const MockUSDCFy = await ethers.getContractFactory("MockUSDC");
    // 通过代理部署合约
    const mockUSDProxy = await MockUSDCFy.deploy();
    // 等待部署完成
    await mockUSDProxy.waitForDeployment();

    const proxyAddress = await mockUSDProxy.getAddress();
    await writeCfg("MockUSDC", {
        abi: MockUSDCFy.interface.format(true),
        address: proxyAddress,
        args: [], // initialize() 没有参数
    });
};

module.exports.tags = ["mockusdc_deploy"];