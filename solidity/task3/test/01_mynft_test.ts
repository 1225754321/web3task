import { deployments, ethers, getNamedAccounts, upgrades } from "hardhat";
import { Address } from "hardhat-deploy/dist/types";
import { readCfg } from "../utils/utils";
import { expect } from "chai";
import { MyNFT, MyNftV2 } from "../typechain-types";

// npx hardhat test test/01_mynft_test.ts 
describe("MyNFT Upgrade", async function () {
    let deployer: Address, user1: Address;
    let myNFTProxyCfg: any;
    let myNFTProxy: MyNFT;
    let myNFTProxyV2: MyNftV2;

    beforeEach(async () => {
        ({ deployer, user1 } = await getNamedAccounts());
        // 部署初始版本合约
        await deployments.fixture(["mynft_deploy"]);
        myNFTProxyCfg = await readCfg("MyNFTProxy");
        myNFTProxy = await ethers.getContractAt("MyNFT", myNFTProxyCfg.address);
    });

    it("测试deploy的MyNFT合约部署初始状态验证", async () => {
        expect(await myNFTProxy.balanceOf(deployer)).to.equal(0);

        await myNFTProxy.MintNFT(deployer, 0, "url0");

        expect(await myNFTProxy.balanceOf(deployer)).to.equal(1);
        expect(await myNFTProxy.ownerOf(0)).to.equal(deployer);
        expect(await myNFTProxy.tokenURI(0)).to.equal("url0");
    });

    it("测试MintNFT传入空url是否抛错", async () => {
        await expect(myNFTProxy.MintNFT(deployer, 10, "")).to.be.
            revertedWithCustomError(myNFTProxy, "InvalidUrl()");
    });


    it("测试MintNFT重复mint同一tokenId行为", async () => {
        await myNFTProxy.MintNFT(deployer, 0, "url0");
        await expect(myNFTProxy.MintNFT(deployer, 0, "url0")).
            to.be.revertedWithCustomError(myNFTProxy, `ERC721InvalidSender`).
            withArgs(ethers.ZeroAddress.toString());
    })

    it("测试只有owner能执行升级操作的权限测试", async () => {
        await expect(myNFTProxy.
            connect(await ethers.getSigner(user1)).
            upgradeToAndCall(await ethers.getSigner(user1), "0x")).to.be.
            revertedWithCustomError(myNFTProxy, `OwnableUnauthorizedAccount`).
            withArgs(user1);
    })

    it("测试initialize函数只能调用一次", async () => {
        await expect(myNFTProxy.__MyNFT_init("", "")).to.be.
            revertedWithCustomError(myNFTProxy, "InvalidInitialization()");
    })

    it("验证MintNFT访问控制权限(调用者限制)", async () => {
        await expect(myNFTProxy.connect(await ethers.getSigner(user1)).MintNFT(deployer, 1, "url1")).
            to.be.revertedWithCustomError(myNFTProxy, "OwnableUnauthorizedAccount").
            withArgs(user1);
    })

    it("测试upgrade的MyNFT合约升级V2", async () => {
        const implBefore = await upgrades.erc1967.getImplementationAddress(await myNFTProxy.getAddress());

        expect(implBefore).to.be.a("string").and.not.empty;

        await deployments.fixture(["mynft_upgrade"]);
        const implAfter = await upgrades.erc1967.getImplementationAddress(await myNFTProxy.getAddress());

        expect(implAfter).to.be.a("string").and.not.empty;
        expect(implAfter).to.not.equal(implBefore);

        myNFTProxyV2 = await ethers.getContractAt("MyNftV2", myNFTProxyCfg.address);
    })

    describe("MyNFT Upgrade V2 Test", async function () {
        beforeEach(async () => {
            await myNFTProxy.MintNFT(deployer, 0, "url0");
            await deployments.fixture(["mynft_upgrade"]);
            myNFTProxyV2 = await ethers.getContractAt("MyNftV2", myNFTProxyCfg.address);
        })
        it("测试升级后数据保持正确", async () => {
            expect(await myNFTProxyV2.balanceOf(deployer)).to.equal(1);
            expect(await myNFTProxyV2.ownerOf(0)).to.equal(deployer);
            expect(await myNFTProxyV2.tokenURI(0)).to.equal("url0");
        })

        it("升级合约后铸造新NFT", async () => {
            await myNFTProxyV2.MintNFT(user1, 1, "url1");

            expect(await myNFTProxyV2.ownerOf(1)).to.equal(user1);
            expect(await myNFTProxyV2.tokenURI(1)).to.equal("url1");
        })

        it("V2 新增函数测试", async () => {
            expect(await myNFTProxyV2.Hello()).to.equal("Hello, MyNTF V2!");
        })
    })
});
