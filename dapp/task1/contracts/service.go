package contracts

import (
	"context"
	"crypto/ecdsa"
	"errors"
	"log"
	"math/big"
	"os"
	"strings"
	"task1/util"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

type ContractService struct {
	savePath   string
	Address    string
	client     *ethclient.Client
	Contracts  *Contracts
	isReDeploy bool
}

func NewContractService(savePath string) *ContractService {
	res := &ContractService{savePath: savePath, client: util.LoadClient()}
	return res.init()

}
func (c *ContractService) SaveAddress() {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}
	path := strings.ReplaceAll(c.savePath, "~", homeDir)
	file, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()
	_, err = file.WriteString(c.Address)
	if err != nil {
		log.Fatal(err)
	}
	err = file.Sync()
	if err != nil {
		log.Fatal(err)
	}
}
func (c *ContractService) Close() {
	defer c.client.Close()
	c.SaveAddress()
}

func (c *ContractService) init() *ContractService {
	if c.savePath == "" {
		c.savePath = "~/.task1_contractsAddress"
	}
	c.Contracts = c.LoadContract()
	return c
}

func (c *ContractService) GetAddress() string {
	if c.Address != "" {
		return c.Address
	}
	homeDir, err := os.UserHomeDir()
	if err != nil {
		log.Fatal(err)
	}
	path := strings.ReplaceAll(c.savePath, "~", homeDir)
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return ""
		}
		log.Println(err)
		return ""
	}
	c.Address = string(data)
	return c.Address
}

func (c *ContractService) SetReDeploy() *ContractService {
	c.isReDeploy = true
	return c
}

// 部署合约并保存合约地址
func (c *ContractService) Deploy() {
	if c.Contracts != nil && !c.isReDeploy {
		return
	}
	log.Println("开始准备部署合约")
	client := c.client

	privateKey, err := crypto.HexToECDSA(util.LoadEnv("<PRIVATE_KEY>"))
	if err != nil {
		log.Fatal(err)
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("cannot assert type: publicKey is not of type *ecdsa.PublicKey")
	}

	fromAddress := crypto.PubkeyToAddress(*publicKeyECDSA)
	nonce, err := client.PendingNonceAt(context.Background(), fromAddress)
	if err != nil {
		log.Fatal(err)
	}

	// gasPrice, err := client.SuggestGasPrice(context.Background())
	// if err != nil {
	// 	log.Fatal(err)
	// }

	chainId, err := client.NetworkID(context.Background())
	if err != nil {
		log.Fatal(err)
	}

	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainId)
	if err != nil {
		log.Fatal(err)
	}
	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = big.NewInt(0)
	// auth.GasLimit = uint64(300000) 默认使用估算值
	// auth.GasPrice = gasPrice 默认使用估算值

	address, tx, contracts, err := DeployContracts(auth, client)
	if err != nil {
		log.Fatal(err)
	}

	receipt, err := util.WaitTransactionReceipt(client, 10, tx.Hash())
	if err != nil {
		log.Fatal(err)
	} else {
		util.ShowReceipt(receipt)
	}

	c.Contracts = contracts
	c.Address = address.Hex()
	c.isReDeploy = false
}

// 获取合约实例
// savePath: 合约地址文件路径
func (c *ContractService) LoadContract() *Contracts {
	if c.Contracts != nil {
		return c.Contracts
	}

	address := c.GetAddress()
	if address == "" {
		return nil
	}

	client := c.client
	contractsAddress := common.HexToAddress(address)
	contracts, err := NewContracts(contractsAddress, client)
	if err != nil {
		log.Println(err)
		return nil
	}
	return contracts
}

// 调用合约方法
func (c *ContractService) Count() {
	contracts := c.LoadContract()
	if contracts == nil {
		log.Fatal("contracts 没有初始化")
	}
	res, err := contracts.Count(nil)
	if err != nil {
		log.Fatal(err)
	}
	log.Println("Count: ", res.Uint64())
}

// 调用合约方法
func (c *ContractService) Increment() {
	log.Println("开始调用合约方法 Increment")
	contracts := c.LoadContract()
	if contracts == nil {
		log.Fatal("contracts 没有初始化")
	}
	privateKey, err := crypto.HexToECDSA(util.LoadEnv("<PRIVATE_KEY>"))
	if err != nil {
		log.Fatal(err)
	}
	chainID, err := c.client.NetworkID(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	opt, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		log.Fatal(err)
	}
	tx, err := contracts.Increment(opt)
	if err != nil {
		log.Fatal(err)
	}
	receipt, err := util.WaitTransactionReceipt(c.client, 10, tx.Hash())
	if err != nil {
		log.Fatal(err)
	}
	util.ShowReceipt(receipt)
}
