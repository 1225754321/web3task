package transactions

import (
	"context"
	"crypto/ecdsa"
	"log"
	"math"
	"math/big"
	"task1/util"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
)

// 准备一个 Sepolia 测试网络的以太坊账户，并获取其私钥。
// 编写 Go 代码，使用 ethclient 连接到 Sepolia 测试网络。
// 构造一笔简单的以太币转账交易，指定发送方、接收方和转账金额。
// 对交易进行签名，并将签名后的交易发送到网络。
// 输出交易的哈希值。
// Transactions 函数用于执行以太坊转账交易
// 参数:
//
//	to - 接收地址的十六进制字符串
//	amount - 转账金额(整数形式)
//	digits - 小数位数
//
// 最终价值: ( amount * 10^digits )wei
//
// 例如:
//
//	amount:1 digits:18 表示转账 1 ETH
//	amount:1 digits:15 表示转账 0.00001 ETH
//	amount:1 digits:1 表示转账 1*10^-18 ETH
func Transactions(to string, amount int64, digits uint) {
	log.Printf("准备向 %s 转账 %d wei 约 %f eth \n", to, amount*int64(math.Pow10(int(digits))), float64(amount)*math.Pow10(int(digits-18)))
	// 加载以太坊客户端
	client := util.LoadClient()
	// 加载私钥
	// 从环境变量中获取私钥字符串并转换为ECDSA私钥对象
	privateKey, err := crypto.HexToECDSA(util.LoadEnv("<PRIVATE_KEY>"))
	if err != nil {
		log.Fatal("私钥解析失败")
	}
	// 获取公钥
	// 从私钥对象获取对应的公钥
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("cannot assert type: publicKey is not of type *ecdsa.PublicKey")
	}
	// 从公钥生成发送者地址
	// 将公钥转换为以太坊地址格式
	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
	// 获取账户当前Nonce
	// Nonce用于确保交易顺序的唯一性
	nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		log.Fatal(err)
	}
	// 设置转账金额和Gas参数
	value := big.NewInt(int64(math.Pow10(int(digits))) * amount) // 转账金额, 例如: 10^(18-5) (以wei为单位) => 0.00001 ETH
	gasLimit := uint64(21000)                                    // Gas限制: 21000 (标准ETH转账)
	// 获取建议的Gas价格
	// SuggestGasPrice 返回网络当前建议的Gas价格
	gasPrice, err := client.SuggestGasPrice(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	// 构建未签名交易
	// types.NewTransaction 创建新的交易对象
	tx := types.NewTransaction(nonce, common.HexToAddress(to), value, gasLimit, gasPrice, nil)
	// 获取网络ID并签名交易
	// NetworkID 返回当前连接的以太坊网络ID
	chainID, err := client.NetworkID(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	// 使用EIP-155签名器签名交易
	// types.SignTx 使用私钥对交易进行签名
	signedTx, err := types.SignTx(tx, types.NewEIP155Signer(chainID), privateKey)
	if err != nil {
		log.Fatal(err)
	}
	// 发送签名交易到网络
	// SendTransaction 广播签名后的交易到以太坊网络
	err = client.SendTransaction(context.Background(), signedTx)
	if err != nil {
		log.Fatal(err)
	}

	receipt, err := util.WaitTransactionReceipt(client, 10, signedTx.Hash())
	if err != nil {
		log.Fatal(err)
	} else {
		util.ShowReceipt(receipt)
	}
}
