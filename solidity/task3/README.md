# NFT 拍卖系统项目

这是一个基于 Hardhat 的 Solidity 项目，实现了一个可升级的 NFT 拍卖系统，包含完整的拍卖工厂和简单拍卖合约。

## 功能说明

本项目包含以下核心合约和功能：

1.  **MyNFT / MyNFTV2**
    *   一个标准的 ERC721 代币合约，用于铸造和管理 NFT。
    *   使用 Hardhat Upgrades 插件实现可升级性。
2.  **MockUSDC**
    *   一个模拟的 ERC20 代币合约，用于在测试和开发环境中作为支付代币。
3.  **ConvertPrice**
    *   一个价格转换工具合约，用于处理不同代币之间的价格换算逻辑。
4.  **NFTAuction / NFTAuctionV2**
    *   NFT 拍卖的核心逻辑合约，负责创建、管理和结算 NFT 拍卖。
    *   使用 Hardhat Upgrades 插件实现可升级性。
5.  **NFTAuctionFactory / NFTAuctionFactoryV2**
    *   NFT 拍卖合约的工厂，用于部署新的 `SimpleAuction` 实例。
    *   使用 Hardhat Upgrades 插件实现可升级性。
6.  **SimpleAuction**
    *   简单的拍卖合约，支持创建、出价、结束和取消拍卖功能。
    *   专注于核心拍卖逻辑，使用 ETH 作为支付代币。

## 部署步骤

### 1. 环境准备

确保您的环境中安装了 Node.js 和 npm/yarn。

### 2. 安装依赖

```bash
npm install
# 或
yarn install
```

### 3. 环境变量配置

在项目根目录创建 `.env` 文件，并填写以下变量：

```
INFURA_API_KEY=
PRIVATE_KEY=
ETH_TO_USD=
USDC_TO_USD=
```

### 4. 编译合约

```bash
npx hardhat compile
```

### 5. 运行测试

```bash
npx hardhat test
```

### 6. 部署合约

本项目使用 `hardhat-deploy` 和 `hardhat-upgrades` 进行部署。部署脚本位于 `deploy/` 目录下。

#### 部署到本地网络

1.  启动 Hardhat 节点：
    ```bash
    npx hardhat node
    ```
2.  在另一个终端运行部署脚本：
    ```bash
    npx hardhat deploy --network localhost
    ```
    部署脚本将按以下顺序执行：
    *   `01_mynft_deploy.ts` (部署 MyNFT)
    *   `03_00_mockusdc_deploy.ts` (部署 MockUSDC)
    *   `03_nftauction_deploy.ts` (部署 NFTAuction)
    *   `05_nftauctionfactory_deploy.ts` (部署 NFTAuctionFactory)

#### 部署到测试网/主网

使用指定的网络名称进行部署：

```bash
npx hardhat deploy --network <network-name>
```
例如：`npx hardhat deploy --network sepolia`

### 7. 合约升级

升级脚本位于 `deploy/` 目录下，例如：

*   升级 MyNFT: `npx hardhat run --network <network-name> deploy/02_mynft_upgrade.ts`
*   升级 NFTAuction: `npx hardhat run --network <network-name> deploy/04_nftauction_upgrade.ts`
*   升级 NFTAuctionFactory: `npx hardhat run --network <network-name> deploy/06_nftauctionfactory_upgrade.ts`

## 部署后操作指南

### 部署过程详解

部署脚本按以下顺序执行，每个步骤完成以下操作：

1. **MyNFT 部署** ([`deploy/01_mynft_deploy.ts`](deploy/01_mynft_deploy.ts:1))
   - 部署可升级的 ERC721 NFT 合约代理
   - 初始化合约：设置 NFT 名称为 "TestNFT"，符号为 "SH_NFT"
   - 合约所有者设置为部署者账户

2. **MockUSDC 部署** ([`deploy/03_00_mockusdc_deploy.ts`](deploy/03_00_mockusdc_deploy.ts:1))
   - 部署模拟 USDC ERC20 代币合约
   - 用于测试环境中的支付代币

3. **NFTAuction 部署** ([`deploy/03_nftauction_deploy.ts`](deploy/03_nftauction_deploy.ts:1))
   - 部署可升级的 NFT 拍卖合约代理
   - 初始化合约：设置 USDC 代币地址
   - 合约所有者设置为部署者账户

4. **NFTAuctionFactory 部署** ([`deploy/05_nftauctionfactory_deploy.ts`](deploy/05_nftauctionfactory_deploy.ts:1))
   - 部署可升级的 NFT 拍卖工厂合约代理
   - 初始化合约：设置合约所有者
   - 用于管理多个 SimpleAuction 合约实例

### 合约操作指南

#### 1. MyNFT 合约操作

**合约地址**: 从部署配置文件中获取 `MyNFTProxy` 地址

**主要功能**:
- **铸造 NFT**: 只有合约所有者可以调用
  ```javascript
  await myNFT.MintNFT(toAddress, tokenId, metadataUrl)
  ```
- **查询 NFT 信息**:
  ```javascript
  await myNFT.ownerOf(tokenId)        // 查询所有者
  await myNFT.tokenURI(tokenId)       // 查询元数据URL
  await myNFT.balanceOf(address)      // 查询余额
  ```

**权限控制**:
- 只有合约所有者可以铸造 NFT
- 任何人都可以查询 NFT 信息

#### 2. MockUSDC 合约操作

**合约地址**: 从部署配置文件中获取 `MockUSDC` 地址

**主要功能**:
- **铸造代币**: 用于测试环境
  ```javascript
  await mockUSDC.mint(toAddress, amount)
  ```
- **转账和授权**:
  ```javascript
  await mockUSDC.transfer(toAddress, amount)
  await mockUSDC.approve(spenderAddress, amount)
  ```

#### 3. NFTAuction 合约操作

**合约地址**: 从部署配置文件中获取 `NFTAuctionProxy` 地址

**主要功能**:

**创建拍卖** (任何人都可以创建):
```javascript
await nftAuction.createAuction(
  nftContractAddress,  // NFT 合约地址
  tokenId,             // NFT token ID
  startingPrice,       // 起始价格 (wei 或 USDC 单位)
  isUSDCPrice,         // true: USDC定价, false: ETH定价
  duration             // 拍卖持续时间 (秒)
)
```

**出价** (支持 ETH 和 USDC):
```javascript
// ETH 出价
await nftAuction.placeBid(
  auctionId,
  0,                  // 对于 ETH 出价设为 0
  ethers.ZeroAddress, // 对于 ETH 出价设为零地址
  { value: bidAmount } // 发送的 ETH 数量
)

// USDC 出价 (需要先授权)
await mockUSDC.approve(nftAuctionAddress, bidAmount)
await nftAuction.placeBid(
  auctionId,
  bidAmount,          // USDC 出价金额
  mockUSDCAddress,    // USDC 合约地址
  { value: 0 }        // 不发送 ETH
)
```

**结束拍卖** (任何人都可以调用):
```javascript
await nftAuction.endAuction(auctionId)
```

**取消拍卖** (只有卖家可以调用):
```javascript
await nftAuction.cancelAuction(auctionId)
```

**查询拍卖信息**:
```javascript
const auction = await nftAuction.auctions(auctionId)
// auction.seller - 卖家地址
// auction.highestBidder - 最高出价者
// auction.highestBid - 最高出价
// auction.startTime - 开始时间
// auction.endTime - 结束时间
// auction.ended - 是否已结束
```

#### 4. NFTAuctionFactory 合约操作

**合约地址**: 从部署配置文件中获取 `NFTAuctionFactoryProxy` 地址

**主要功能**:

**创建拍卖合约** (只有工厂所有者可以调用):
```javascript
await nftAuctionFactory.createAuction(
  nftContractAddress,    // NFT 合约地址
  tokenId,               // NFT token ID
  startingPrice,         // 起始价格 (wei)
  duration               // 拍卖持续时间 (秒)
)
```

**查询功能**:
```javascript
// 获取所有拍卖合约
const auctions = await nftAuctionFactory.getAuctions()

// 根据 ID 获取特定拍卖
const auctionAddress = await nftAuctionFactory.getAuction(auctionId)

// 获取下一个拍卖 ID
const nextId = await nftAuctionFactory.nextAuctionId()
```

#### 5. SimpleAuction 合约操作

**合约地址**: 通过 NFTAuctionFactory 创建后获取

**主要功能**:

**出价** (使用 ETH 出价):
```javascript
await simpleAuction.placeBid({ value: bidAmount })
```

**结束拍卖** (只有卖家可以调用):
```javascript
await simpleAuction.endAuction()
```

**取消拍卖** (只有卖家可以调用):
```javascript
await simpleAuction.cancelAuction()
```

**查询拍卖信息**:
```javascript
const auctionInfo = await simpleAuction.getAuctionInfo()
// auctionInfo.seller - 卖家地址
// auctionInfo.nftContract - NFT 合约地址
// auctionInfo.tokenId - NFT token ID
// auctionInfo.startingPrice - 起始价格
// auctionInfo.highestBid - 最高出价
// auctionInfo.highestBidder - 最高出价者
// auctionInfo.startTime - 开始时间
// auctionInfo.endTime - 结束时间
// auctionInfo.status - 拍卖状态 (0: Active, 1: Ended, 2: Cancelled)
```

**检查拍卖状态**:
```javascript
const isActive = await simpleAuction.isActive()
```

### 价格转换功能

系统使用 Chainlink 预言机进行价格转换，支持 ETH/USD 和 USDC/USD 转换：

```javascript
// 设置预言机地址 (只有合约所有者可以调用)
await nftAuction.aggregatorV3Interface(convertType, aggregatorAddress)

// 查询价格转换
const usdValue = await nftAuction.convert(convertType, amount)
```

### 重要注意事项

1. **权限管理**:
   - MyNFT 铸造：只有合约所有者
   - NFTAuctionFactory 创建拍卖：只有工厂所有者
   - SimpleAuction 结束/取消拍卖：只有卖家
   - 合约升级：只有合约所有者

2. **时间限制**:
   - SimpleAuction：拍卖持续时间必须大于0
   - NFTAuction：最小拍卖时长1小时，最大7天

3. **出价规则**:
   - SimpleAuction：只支持 ETH 出价，出价必须高于当前最高出价
   - NFTAuction：支持 ETH 和 USDC 出价，不能同时使用两种代币

4. **退款机制**:
   - 当有更高出价时，前一出价者自动获得退款
   - 拍卖取消时，所有出价者获得退款

5. **安全特性**:
   - 可升级合约包含重入保护
   - 使用 SafeERC20 进行安全的代币转账
   - 支持 UUPS 可升级模式

### 测试和验证

运行测试以确保所有功能正常工作：
```bash
npx hardhat test
```

查看部署配置：
```bash
cat .cfg/*.json
```

### 常见操作流程

1. **SimpleAuction 流程** (通过工厂创建):
   - 部署者铸造 NFT
   - NFT 所有者授权工厂合约
   - 通过 NFTAuctionFactory 创建 SimpleAuction
   - 参与者使用 ETH 出价
   - 卖家结束拍卖，NFT 转移给最高出价者

2. **NFTAuction 流程** (直接使用):
   - 部署者铸造 NFT
   - NFT 所有者直接创建拍卖
   - 参与者使用 ETH 或 USDC 出价
   - 拍卖结束后 NFT 转移给最高出价者

3. **拍卖管理流程**:
   - 卖家可以随时取消拍卖（在结束前）
   - 卖家可以在拍卖结束后调用结束函数
   - 系统自动处理退款和转账

4. **工厂管理流程**:
   - 工厂所有者可以创建多个拍卖合约
   - 可以查询所有创建的拍卖合约
   - 每个拍卖都有唯一的 ID 标识
