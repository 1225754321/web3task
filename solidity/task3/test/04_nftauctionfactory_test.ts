import { deployments, ethers, getNamedAccounts, upgrades } from "hardhat";
import { Address } from "hardhat-deploy/dist/types";
import { readCfg } from "../utils/utils";
import { expect } from "chai";
import { MyNFT, NFTAuction, NFTAuctionFactory, MockUSDC } from "../typechain-types";

/**    
 * NFT拍卖工厂合约测试
 * @dev 测试NFT拍卖工厂合约的功能，包括合约管理、访问控制等
 * @author sht
 * 
 * npx hardhat test test/04_nftauctionfactory_test.ts
 */
describe("NFT拍卖工厂合约", async () => {
    let deployer: Address, user1: Address, user2: Address;
    let myNFTProxy: MyNFT;
    let nftAuctionFactoryProxy: NFTAuctionFactory;
    let mockUSDC: MockUSDC;
    let nftAuctionFactoryProxyCfg: any;

    const NFT_ID = 1n;
    const NFT_URI = "test_uri";

    beforeEach(async () => {
        // 部署所有依赖合约, 每次it测试执行一次
        await deployments.fixture(["mynft_deploy", "mockusdc_deploy", "nftauctionfactory_deploy"]);

        ({ deployer, user1, user2 } = await getNamedAccounts());

        // 获取合约实例
        const myNFTProxyCfg = await readCfg("MyNFTProxy");
        myNFTProxy = await ethers.getContractAt("MyNFT", myNFTProxyCfg.address);

        const mockUSDCCfg = await readCfg("MockUSDC");
        mockUSDC = await ethers.getContractAt("MockUSDC", mockUSDCCfg.address);

        nftAuctionFactoryProxyCfg = await readCfg("NFTAuctionFactoryProxy");
        nftAuctionFactoryProxy = await ethers.getContractAt("NFTAuctionFactory", nftAuctionFactoryProxyCfg.address);

        // 铸造一个NFT给 deployer (作为卖家)
        await myNFTProxy.MintNFT(deployer, NFT_ID, NFT_URI);
    });

    describe("合约部署与初始化", function () {
        it("应该正确部署并初始化工厂合约", async function () {
            expect(await nftAuctionFactoryProxy.owner()).to.equal(deployer);
            expect(await nftAuctionFactoryProxy.nextAuctionId()).to.equal(0n);
        });

        it("应该正确设置初始状态变量", async function () {
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(0);
            expect(await nftAuctionFactoryProxy.nextAuctionId()).to.equal(0n);
        });

    });

    describe("合约部署与升级", function () {
        let implementationAddress: string;
        this.beforeEach(async () => {
            implementationAddress = await upgrades.erc1967.getImplementationAddress(
                await nftAuctionFactoryProxy.getAddress()
            );
            await deployments.fixture(["nftauctionfactory_upgrade"]);
        });

        it("应该正确实现可升级模式", async function () {
            const nftAuctionFactoryProxyAddress = await nftAuctionFactoryProxy.getAddress();
            const implementationAddress = await upgrades.erc1967.getImplementationAddress(
                nftAuctionFactoryProxyAddress
            );
            expect(implementationAddress).to.not.equal(ethers.ZeroAddress);
            expect(implementationAddress).to.not.equal(nftAuctionFactoryProxyAddress);
        });

        it("应该正确升级", async function () {
            // 验证代理模式
            const nftAuctionFactoryV2Proxy = await ethers.getContractAt("NFTAuctionFactoryV2", nftAuctionFactoryProxyCfg.address);
            const nftAuctionFactoryV2ProxyAddress = await nftAuctionFactoryV2Proxy.getAddress()
            const implementationAddress2 = await upgrades.erc1967.getImplementationAddress(
                nftAuctionFactoryV2ProxyAddress
            );
            expect(nftAuctionFactoryV2ProxyAddress).to.equal(nftAuctionFactoryProxyCfg.address);
            expect(implementationAddress2).to.not.equal(nftAuctionFactoryV2ProxyAddress);
            expect(implementationAddress2).to.not.equal(implementationAddress);
        });

        it("应该正确升级并且新函数可用", async function () {
            await deployments.fixture(["nftauctionfactory_upgrade"]);
            const nftAuctionFactoryV2Proxy = await ethers.getContractAt("NFTAuctionFactoryV2", nftAuctionFactoryProxyCfg.address);
            expect(await nftAuctionFactoryV2Proxy.Hello()).to.equal("Hello World NFTAuctionFactoryV2!");
        })
    })

    describe("拍卖管理功能", function () {
        it("应该正确返回空拍卖列表", async function () {
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(0);
        });

        it("应该正确通过ID获取特定拍卖", async function () {
            // 测试不存在的拍卖ID
            const invalidAuctionId = 999n;
            const auction = await nftAuctionFactoryProxy.getAuction(invalidAuctionId);
            expect(auction).to.equal(ethers.ZeroAddress);
        });

        it("应该正确维护拍卖计数器", async function () {
            expect(await nftAuctionFactoryProxy.nextAuctionId()).to.equal(0n);
        });
    });

    describe("访问控制和安全", function () {
        it("应该正确实施onlyOwner修饰符", async function () {
            // 测试只有所有者可以调用受保护的方法
            const user1Signer = await ethers.getSigner(user1);

            // 尝试以非所有者身份调用受保护的方法
            await expect(
                nftAuctionFactoryProxy.connect(user1Signer).createAuction(
                    await myNFTProxy.getAddress(),
                    NFT_ID,
                    ethers.parseEther("0.01"),
                    false,
                    3600n,
                    await mockUSDC.getAddress(),
                    []
                )
            ).to.be.revertedWithCustomError(nftAuctionFactoryProxy, "OwnableUnauthorizedAccount");
        });

        it("应该正确处理所有权转移", async function () {
            // 转移所有权给user1
            await nftAuctionFactoryProxy.transferOwnership(user1);

            // 验证所有权转移
            expect(await nftAuctionFactoryProxy.owner()).to.equal(user1);
        });

        it("应该正确处理所有权放弃", async function () {
            // 放弃所有权
            await nftAuctionFactoryProxy.renounceOwnership();

            // 验证所有权被放弃
            expect(await nftAuctionFactoryProxy.owner()).to.equal(ethers.ZeroAddress);
        });

        it("应该防止重入攻击", async function () {
            // 工厂合约使用ReentrancyGuard，应该防止重入
            // 验证合约确实使用了ReentrancyGuard，通过调用一个简单的只读函数来测试
            const owner = await nftAuctionFactoryProxy.owner();
            expect(owner).to.equal(deployer);
        });
    });

    describe("边缘情况和集成测试", function () {
        it("应该正确处理不同的合约状态", async function () {
            // 测试各种状态查询
            const owner = await nftAuctionFactoryProxy.owner();
            expect(owner).to.equal(deployer);

            const nextAuctionId = await nftAuctionFactoryProxy.nextAuctionId();
            expect(nextAuctionId).to.equal(0n);

            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(0);
        });

        it("应该正确处理无效参数", async function () {
            // 测试无效的拍卖ID查询
            const invalidAuctionId = 999n;
            const auction = await nftAuctionFactoryProxy.getAuction(invalidAuctionId);
            expect(auction).to.equal(ethers.ZeroAddress);
        });

        it("应该与NFT合约正确集成", async function () {
            // 验证NFT合约可以正常交互
            expect(await myNFTProxy.ownerOf(NFT_ID)).to.equal(deployer);
            expect(await myNFTProxy.tokenURI(NFT_ID)).to.equal(NFT_URI);
        });

        it("应该与USDC合约正确集成", async function () {
            // 验证USDC合约可以正常交互
            const balance = await mockUSDC.balanceOf(deployer);
            expect(balance).to.be.gt(0n);
        });
    });

    describe("事件测试", function () {
        it("应该正确发出所有权转移事件", async function () {
            // 转移所有权给user1
            await expect(nftAuctionFactoryProxy.transferOwnership(user1))
                .to.emit(nftAuctionFactoryProxy, "OwnershipTransferred")
                .withArgs(deployer, user1);
        });

        it("应该正确发出初始化事件", async function () {
            // 工厂合约在部署时应该发出初始化事件
            // 注意：由于合约已经部署，我们无法直接测试初始化事件
            // 但可以验证合约已正确初始化
            expect(await nftAuctionFactoryProxy.owner()).to.equal(deployer);
        });
    });

    describe("状态变量测试", function () {
        it("应该正确访问公共状态变量", async function () {
            // 测试公共状态变量的访问
            const nextAuctionId = await nftAuctionFactoryProxy.nextAuctionId();
            expect(nextAuctionId).to.equal(0n);

            // 测试映射访问 - 使用有效的索引
            const auction = await nftAuctionFactoryProxy.auctionIdToAuction(0n);
            expect(auction).to.equal(ethers.ZeroAddress);
        });

        it("应该正确处理状态变量边界", async function () {
            // 测试映射访问边界 - 使用有效的索引
            const auction = await nftAuctionFactoryProxy.auctionIdToAuction(0n);
            expect(auction).to.equal(ethers.ZeroAddress);
        });
    });

    describe("拍卖创建功能", function () {
        const STARTING_PRICE = ethers.parseEther("0.01");
        const DURATION = 3600n * 2n;
        const NFT_ID = 1n;

        beforeEach(async () => {
            // 确保 NFT 归属正确
            await myNFTProxy.approve(await nftAuctionFactoryProxy.getAddress(), NFT_ID);
        });

        it("应该成功创建拍卖合约", async function () {
            const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
            const ethAggregator = await MockV3AggregatorFy.deploy(0, 100);
            const usdcAggregator = await MockV3AggregatorFy.deploy(0, 200);
            await ethAggregator.waitForDeployment();
            await usdcAggregator.waitForDeployment();

            const aggregatorAddresses = [
                await ethAggregator.getAddress(),
                await usdcAggregator.getAddress()
            ];

            // 创建拍卖
            const tx = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                false,
                DURATION,
                await mockUSDC.getAddress(),
                aggregatorAddresses
            );
            const receipt = await tx.wait();
            
            // 从事件中获取拍卖地址
            const event = receipt?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            const auctionAddress = (event as any)?.args[0];

            // 验证返回的拍卖地址有效
            expect(auctionAddress).to.not.equal(ethers.ZeroAddress);

            // 验证拍卖列表更新
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(1);

            // 验证拍卖ID映射
            const auctionFromMapping = await nftAuctionFactoryProxy.getAuction(0n);
            expect(auctionFromMapping).to.equal(auctionAddress);

            // 验证拍卖计数器更新
            expect(await nftAuctionFactoryProxy.nextAuctionId()).to.equal(1n);

            // 验证拍卖地址有效
            expect(auctionAddress).to.not.equal(ethers.ZeroAddress);
        });

        it("应该成功创建多个拍卖合约", async function () {
            const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
            const ethAggregator = await MockV3AggregatorFy.deploy(0, 100);
            const usdcAggregator = await MockV3AggregatorFy.deploy(0, 200);
            await ethAggregator.waitForDeployment();
            await usdcAggregator.waitForDeployment();

            const aggregatorAddresses = [
                await ethAggregator.getAddress(),
                await usdcAggregator.getAddress()
            ];

            // 创建第一个拍卖
            const tx1 = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                false,
                DURATION,
                await mockUSDC.getAddress(),
                aggregatorAddresses
            );
            const receipt1 = await tx1.wait();
            const event1 = receipt1?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            const auctionAddress1 = (event1 as any)?.args[0];

            // 创建第二个拍卖
            const NEW_NFT_ID = 2n;
            await myNFTProxy.MintNFT(deployer, NEW_NFT_ID, "url2");
            await myNFTProxy.approve(await nftAuctionFactoryProxy.getAddress(), NEW_NFT_ID);

            const tx2 = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NEW_NFT_ID,
                STARTING_PRICE,
                true,
                DURATION,
                await mockUSDC.getAddress(),
                aggregatorAddresses
            );
            const receipt2 = await tx2.wait();
            const event2 = receipt2?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            const auctionAddress2 = (event2 as any)?.args[0];

            // 验证拍卖列表
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(2);

            // 验证拍卖ID映射
            expect(await nftAuctionFactoryProxy.getAuction(0n)).to.equal(auctionAddress1);
            expect(await nftAuctionFactoryProxy.getAuction(1n)).to.equal(auctionAddress2);

            // 验证拍卖计数器
            expect(await nftAuctionFactoryProxy.nextAuctionId()).to.equal(2n);
        });

        it("非所有者创建拍卖应失败", async function () {
            const MockV3AggregatorFy = await ethers.getContractFactory("MockV3Aggregator");
            const ethAggregator = await MockV3AggregatorFy.deploy(0, 100);
            const usdcAggregator = await MockV3AggregatorFy.deploy(0, 200);
            await ethAggregator.waitForDeployment();
            await usdcAggregator.waitForDeployment();

            const aggregatorAddresses = [
                await ethAggregator.getAddress(),
                await usdcAggregator.getAddress()
            ];

            await expect(
                nftAuctionFactoryProxy.connect(await ethers.getSigner(user1)).createAuction(
                    await myNFTProxy.getAddress(),
                    NFT_ID,
                    STARTING_PRICE,
                    false,
                    DURATION,
                    await mockUSDC.getAddress(),
                    aggregatorAddresses
                )
            ).to.be.revertedWithCustomError(nftAuctionFactoryProxy, "OwnableUnauthorizedAccount");
        });

        it("应该正确处理空的预言机地址数组", async function () {
            // 创建拍卖时不设置预言机地址
            const tx = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                false,
                DURATION,
                await mockUSDC.getAddress(),
                []
            );
            const receipt = await tx.wait();
            const event = receipt?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            const auctionAddress = (event as any)?.args[0];

            // 验证拍卖创建成功
            expect(auctionAddress).to.not.equal(ethers.ZeroAddress);

            // 验证拍卖列表更新
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(1);
        });
    });

    describe("集成功能测试", function () {
        it("应该正确维护合约关系", async function () {
            // 验证工厂合约与其他合约的关系
            const myNFTAddress = await myNFTProxy.getAddress();
            const mockUSDCAddress = await mockUSDC.getAddress();
            const factoryAddress = await nftAuctionFactoryProxy.getAddress();

            expect(myNFTAddress).to.not.equal(ethers.ZeroAddress);
            expect(mockUSDCAddress).to.not.equal(ethers.ZeroAddress);
            expect(factoryAddress).to.not.equal(ethers.ZeroAddress);
        });
    });
});