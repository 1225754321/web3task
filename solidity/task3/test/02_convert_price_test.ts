import { ethers } from "hardhat"
import { ConvertPrice } from "../typechain-types"
import { expect } from "chai";

// 网络不好的话需要开启代理
// npx hardhat test test/02_convert_price_test.ts --network sepolia
describe("ConvertPrice", async () => {
    let convertPrice: ConvertPrice
    beforeEach(async () => {
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
})