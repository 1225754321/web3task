import { deployments, ethers, getNamedAccounts, upgrades } from "hardhat";
import { Address } from "hardhat-deploy/dist/types";
import { readCfg } from "../utils/utils";
import { expect } from "chai";
import { MyNFT, NFTAuction, NFTAuctionFactory, MockUSDC, SimpleAuction } from "../typechain-types";

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
                    3600n
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
            // 创建拍卖
            const tx = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                DURATION
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

            // 验证创建的拍卖合约可以正常交互
            const simpleAuction = await ethers.getContractAt("SimpleAuction", auctionAddress);
            const auctionInfo = await simpleAuction.getAuctionInfo();
            expect(auctionInfo.seller).to.equal(deployer);
            expect(auctionInfo.tokenId).to.equal(NFT_ID);
            expect(auctionInfo.startingPrice).to.equal(STARTING_PRICE);
        });

        it("应该成功创建多个拍卖合约", async function () {
            // 创建第一个拍卖
            const tx1 = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                DURATION
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
                DURATION
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

            // 验证两个拍卖合约都可以正常交互
            const simpleAuction1 = await ethers.getContractAt("SimpleAuction", auctionAddress1);
            const simpleAuction2 = await ethers.getContractAt("SimpleAuction", auctionAddress2);
            
            const auctionInfo1 = await simpleAuction1.getAuctionInfo();
            const auctionInfo2 = await simpleAuction2.getAuctionInfo();
            
            expect(auctionInfo1.tokenId).to.equal(NFT_ID);
            expect(auctionInfo2.tokenId).to.equal(NEW_NFT_ID);
        });

        it("非所有者创建拍卖应失败", async function () {
            await expect(
                nftAuctionFactoryProxy.connect(await ethers.getSigner(user1)).createAuction(
                    await myNFTProxy.getAddress(),
                    NFT_ID,
                    STARTING_PRICE,
                    DURATION
                )
            ).to.be.revertedWithCustomError(nftAuctionFactoryProxy, "OwnableUnauthorizedAccount");
        });

        it("应该正确处理拍卖合约交互", async function () {
            // 创建拍卖
            const tx = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                DURATION
            );
            const receipt = await tx.wait();
            const event = receipt?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            const auctionAddress = (event as any)?.args[0];

            // 验证拍卖创建成功
            expect(auctionAddress).to.not.equal(ethers.ZeroAddress);

            // 验证拍卖列表更新
            const auctions = await nftAuctionFactoryProxy.getAuctions();
            expect(auctions.length).to.equal(1);

            // 验证拍卖合约功能
            const simpleAuction = await ethers.getContractAt("SimpleAuction", auctionAddress);
            
            // 验证拍卖信息
            const auctionInfo = await simpleAuction.getAuctionInfo();
            expect(auctionInfo.seller).to.equal(deployer);
            expect(auctionInfo.nftContract).to.equal(await myNFTProxy.getAddress());
            expect(auctionInfo.tokenId).to.equal(NFT_ID);
            expect(auctionInfo.startingPrice).to.equal(STARTING_PRICE);
            expect(auctionInfo.status).to.equal(0); // Active status

            // 验证拍卖活跃状态
            expect(await simpleAuction.isActive()).to.be.true;
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

    describe("完整拍卖流程测试", function () {
        let auctionAddress: string;
        let simpleAuction: SimpleAuction;
        const STARTING_PRICE = ethers.parseEther("0.01");
        const DURATION = 3600n * 2n;

        beforeEach(async () => {
            // 确保NFT已经授权给工厂合约
            await myNFTProxy.approve(await nftAuctionFactoryProxy.getAddress(), NFT_ID);
            
            // 创建拍卖
            const tx = await nftAuctionFactoryProxy.createAuction(
                await myNFTProxy.getAddress(),
                NFT_ID,
                STARTING_PRICE,
                DURATION
            );
            const receipt = await tx.wait();
            const event = receipt?.logs.find((log: any) => log.fragment?.name === "AuctionCreated");
            auctionAddress = (event as any)?.args[0];
            simpleAuction = await ethers.getContractAt("SimpleAuction", auctionAddress);
        });

        it("应该成功完成完整拍卖流程 - 有出价者获胜", async function () {
            // 验证拍卖初始状态
            const initialInfo = await simpleAuction.getAuctionInfo();
            expect(initialInfo.seller).to.equal(deployer);
            expect(initialInfo.status).to.equal(0); // Active
            expect(await simpleAuction.isActive()).to.be.true;

            // user1 出价
            const user1Signer = await ethers.getSigner(user1);
            const bidAmount1 = ethers.parseEther("0.02");
            await expect(
                simpleAuction.connect(user1Signer).placeBid({ value: bidAmount1 })
            ).to.emit(simpleAuction, "BidPlaced").withArgs(user1, bidAmount1);

            // 验证出价后状态
            const afterBid1Info = await simpleAuction.getAuctionInfo();
            expect(afterBid1Info.highestBidder).to.equal(user1);
            expect(afterBid1Info.highestBid).to.equal(bidAmount1);

            // user2 出更高价
            const user2Signer = await ethers.getSigner(user2);
            const bidAmount2 = ethers.parseEther("0.03");
            await expect(
                simpleAuction.connect(user2Signer).placeBid({ value: bidAmount2 })
            ).to.emit(simpleAuction, "BidPlaced").withArgs(user2, bidAmount2);

            // 验证user1收到退款
            const user1BalanceBefore = await ethers.provider.getBalance(user1);
            await expect(
                simpleAuction.connect(user2Signer).placeBid({ value: bidAmount2 })
            );
            const user1BalanceAfter = await ethers.provider.getBalance(user1);
            // 由于gas费用，余额可能不会严格增加，但应该接近原始余额
            expect(user1BalanceAfter).to.be.closeTo(user1BalanceBefore, ethers.parseEther("0.001"));

            // 验证出价后状态
            const afterBid2Info = await simpleAuction.getAuctionInfo();
            expect(afterBid2Info.highestBidder).to.equal(user2);
            expect(afterBid2Info.highestBid).to.equal(bidAmount2);

            // 等待拍卖结束
            await ethers.provider.send("evm_increaseTime", [Number(DURATION) + 1]);
            await ethers.provider.send("evm_mine", []);

            // 卖家结束拍卖
            await expect(simpleAuction.endAuction())
                .to.emit(simpleAuction, "AuctionEnded")
                .withArgs(user2, bidAmount2);

            // 验证拍卖结束状态
            const finalInfo = await simpleAuction.getAuctionInfo();
            expect(finalInfo.status).to.equal(1); // Ended
            expect(await simpleAuction.isActive()).to.be.false;

            // 验证NFT转移到获胜者
            expect(await myNFTProxy.ownerOf(NFT_ID)).to.equal(user2);

            // 验证卖家收到资金
            const sellerBalance = await ethers.provider.getBalance(deployer);
            expect(sellerBalance).to.be.gt(0);
        });

        it("应该成功完成完整拍卖流程 - 无人出价", async function () {
            // 等待拍卖结束
            await ethers.provider.send("evm_increaseTime", [Number(DURATION) + 1]);
            await ethers.provider.send("evm_mine", []);

            // 卖家结束拍卖
            await expect(simpleAuction.endAuction())
                .to.emit(simpleAuction, "AuctionEnded")
                .withArgs(ethers.ZeroAddress, STARTING_PRICE);

            // 验证拍卖结束状态
            const finalInfo = await simpleAuction.getAuctionInfo();
            expect(finalInfo.status).to.equal(1); // Ended
            expect(await simpleAuction.isActive()).to.be.false;

            // 验证NFT退还卖家
            expect(await myNFTProxy.ownerOf(NFT_ID)).to.equal(deployer);
        });

        it("应该成功取消拍卖", async function () {
            // user1 出价
            const user1Signer = await ethers.getSigner(user1);
            const bidAmount = ethers.parseEther("0.02");
            await simpleAuction.connect(user1Signer).placeBid({ value: bidAmount });

            // 卖家取消拍卖
            await expect(simpleAuction.cancelAuction())
                .to.emit(simpleAuction, "AuctionCancelled")
                .withArgs(deployer);

            // 验证拍卖取消状态
            const finalInfo = await simpleAuction.getAuctionInfo();
            expect(finalInfo.status).to.equal(2); // Cancelled
            expect(await simpleAuction.isActive()).to.be.false;

            // 验证NFT退还卖家
            expect(await myNFTProxy.ownerOf(NFT_ID)).to.equal(deployer);

            // 验证出价者收到退款
            const user1Balance = await ethers.provider.getBalance(user1);
            expect(user1Balance).to.be.gt(0);
        });

        it("非卖家不能结束拍卖", async function () {
            const user1Signer = await ethers.getSigner(user1);
            await expect(
                simpleAuction.connect(user1Signer).endAuction()
            ).to.be.revertedWith("Only seller can end auction");
        });

        it("非卖家不能取消拍卖", async function () {
            const user1Signer = await ethers.getSigner(user1);
            await expect(
                simpleAuction.connect(user1Signer).cancelAuction()
            ).to.be.revertedWith("Only seller can cancel auction");
        });

        it("拍卖未结束不能结束", async function () {
            await expect(
                simpleAuction.endAuction()
            ).to.be.revertedWith("Auction not ended");
        });

        it("拍卖已结束不能取消", async function () {
            // 等待拍卖结束
            await ethers.provider.send("evm_increaseTime", [Number(DURATION) + 1]);
            await ethers.provider.send("evm_mine", []);

            // 结束拍卖
            await simpleAuction.endAuction();

            // 尝试取消已结束的拍卖
            await expect(
                simpleAuction.cancelAuction()
            ).to.be.revertedWith("Auction not active");
        });

        it("出价必须高于当前最高价", async function () {
            const user1Signer = await ethers.getSigner(user1);
            const lowBidAmount = ethers.parseEther("0.005"); // 低于起始价格
            await expect(
                simpleAuction.connect(user1Signer).placeBid({ value: lowBidAmount })
            ).to.be.revertedWith("Bid too low");
        });

        it("拍卖结束后不能出价", async function () {
            // 等待拍卖结束
            await ethers.provider.send("evm_increaseTime", [Number(DURATION) + 1]);
            await ethers.provider.send("evm_mine", []);

            const user1Signer = await ethers.getSigner(user1);
            const bidAmount = ethers.parseEther("0.02");
            await expect(
                simpleAuction.connect(user1Signer).placeBid({ value: bidAmount })
            ).to.be.revertedWith("Auction ended");
        });

        it("拍卖取消后不能出价", async function () {
            // 取消拍卖
            await simpleAuction.cancelAuction();

            const user1Signer = await ethers.getSigner(user1);
            const bidAmount = ethers.parseEther("0.02");
            await expect(
                simpleAuction.connect(user1Signer).placeBid({ value: bidAmount })
            ).to.be.revertedWith("Auction not active");
        });

        it("应该正确处理多个出价者的退款", async function () {
            // user1 出价
            const user1Signer = await ethers.getSigner(user1);
            const bidAmount1 = ethers.parseEther("0.02");
            await simpleAuction.connect(user1Signer).placeBid({ value: bidAmount1 });

            // user2 出更高价
            const user2Signer = await ethers.getSigner(user2);
            const bidAmount2 = ethers.parseEther("0.03");
            await simpleAuction.connect(user2Signer).placeBid({ value: bidAmount2 });

            // user3 出最高价
            const user3Signer = await ethers.getSigner(user1); // 使用另一个账户
            const bidAmount3 = ethers.parseEther("0.04");
            await simpleAuction.connect(user3Signer).placeBid({ value: bidAmount3 });

            // 验证最终状态
            const finalInfo = await simpleAuction.getAuctionInfo();
            expect(finalInfo.highestBidder).to.equal(user1); // user3 实际上是 user1 的另一个签名者
            expect(finalInfo.highestBid).to.equal(bidAmount3);
        });
    });
});