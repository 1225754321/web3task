import { ethers, getNamedAccounts } from "hardhat"
import { ConvertPrice } from "../typechain-types"
import { expect } from "chai";

// 网络不好的话需要开启代理
// npx hardhat test test/02_convert_price_test.ts --network sepolia
describe("ConvertPrice", async () => {
    let convertPrice: ConvertPrice
    let deployer: string, user1: string;

    beforeEach(async () => {
        const accounts = await getNamedAccounts();
        deployer = accounts.deployer;
        user1 = accounts.user1;

        const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
        const m1 = await MockV3AggregatorFy.deploy(0, 100);
        const m2 = await MockV3AggregatorFy.deploy(0, 200);
        await m1.waitForDeployment();
        await m2.waitForDeployment();
        const convertPriceFy = await ethers.getContractFactory("ConvertPrice");
        convertPrice = await convertPriceFy.deploy();
        await convertPrice.waitForDeployment();
        await convertPrice.__ConvertPrice_init();
        await convertPrice.aggregatorV3Interface(0, await m1.getAddress());
        await convertPrice.aggregatorV3Interface(1, await m2.getAddress());

    })
    it("test getChainlinkDataFeedLatestAnswer", async () => {
        const ethToUSD = await convertPrice.getChainlinkDataFeedLatestAnswer(0n);
        const usdcToUSD = await convertPrice.getChainlinkDataFeedLatestAnswer(1n);
        expect(ethToUSD).to.be.not.equal(0);
        expect(usdcToUSD).to.be.not.equal(0);
        console.log("ETH to USD: ", ethToUSD);
        console.log("USDC to USD: ", usdcToUSD);
    })
    it("test convert", async () => {
        const ethToUSD = await convertPrice.convert(0, 100);
        const usdcToUSD = await convertPrice.convert(1, 100);
        expect(ethToUSD).to.be.not.equal(0);
        expect(usdcToUSD).to.be.not.equal(0);
        console.log("ETH to USD: ", ethToUSD);
        console.log("USDC to USD: ", usdcToUSD);
    })

    describe("权限控制测试", function () {
        let user1Signer: any;

        beforeEach(async () => {
            user1Signer = await ethers.getSigner(user1);
        });

        it("只有所有者可以设置预言机地址", async function () {
            const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
            const newAggregator = await MockV3AggregatorFy.deploy(0, 300);
            await newAggregator.waitForDeployment();

            // 所有者设置预言机地址应该成功
            await expect(
                convertPrice.aggregatorV3Interface(0n, await newAggregator.getAddress())
            ).to.not.be.reverted;

            // 非所有者设置预言机地址应该失败
            await expect(
                convertPrice.connect(user1Signer).aggregatorV3Interface(0n, await newAggregator.getAddress())
            ).to.be.revertedWithCustomError(convertPrice, "OwnableUnauthorizedAccount");
        });

        it("设置预言机地址后应能正确获取价格", async function () {
            const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
            const newAggregator = await MockV3AggregatorFy.deploy(0, 300);
            await newAggregator.waitForDeployment();

            // 设置新的预言机地址
            await convertPrice.aggregatorV3Interface(0n, await newAggregator.getAddress());

            // 验证能正确获取新价格
            const price = await convertPrice.getChainlinkDataFeedLatestAnswer(0n);
            expect(price).to.equal(300n);
        });
    });

    describe("错误处理测试", function () {
        it("未设置预言机地址时应正确处理", async function () {
            // 创建一个新的 ConvertPrice 实例，不设置预言机
            const convertPriceFy = await ethers.getContractFactory("ConvertPrice");
            const newConvertPrice = await convertPriceFy.deploy();
            await newConvertPrice.waitForDeployment();
            await newConvertPrice.__ConvertPrice_init();

            // 尝试获取未设置的预言机价格应该失败
            await expect(
                newConvertPrice.getChainlinkDataFeedLatestAnswer(0n)
            ).to.be.reverted;
        });

        it("零金额转换应返回零", async function () {
            const result = await convertPrice.convert(0n, 0);
            expect(result).to.equal(0n);
        });
    });
})