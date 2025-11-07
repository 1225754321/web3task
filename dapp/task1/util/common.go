package util

import (
	"context"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/ethereum/go-ethereum/rpc"
	"github.com/gorilla/websocket"
)

const (
	EMPTY_ADDRESS = "0x0000000000000000000000000000000000000000"
)

func loadProxyClient() *http.Client {
	// 1. 设置代理服务器地址
	proxyUrl, _ := url.Parse("socks5://127.0.0.1:7897")
	// 2. 创建一个自定义的 HTTP Transport，配置代理
	customTransport := &http.Transport{
		Proxy: http.ProxyURL(proxyUrl),
		// 可根据需要配置其他参数，如DialContext、TLS握手超时等
	}
	// 3. 使用自定义的 Transport 创建 HTTP 客户端
	httpClient := &http.Client{
		Transport: customTransport,
	}
	return httpClient
}

func LoadClient() *ethclient.Client {
	return loadClientBase(LoadEnv("https://sepolia.infura.io/v3/<API_KEY>"), rpc.WithHTTPClient(loadProxyClient()))
}

func LoadClientWs() *ethclient.Client {
	// return loadClientBase(LoadEnv("wss://sepolia.infura.io/ws/v3/<API_KEY>"), rpc.WithWebsocketDialer(loadClientWithWs()))
	// wss://ethereum-sepolia-rpc.publicnode.com 上面那个官方地址有问题，查询出来的区块信息异常在链上查不到，得用下面这个
	return loadClientBase(LoadEnv("wss://ethereum-sepolia-rpc.publicnode.com/<API_KEY>"), rpc.WithWebsocketDialer(loadClientWithWs()))
}

func loadClientWithWs() websocket.Dialer {
	proxyUrl, _ := url.Parse("socks5://127.0.0.1:7897")
	websocket.DefaultDialer.Proxy = http.ProxyURL(proxyUrl)
	return *websocket.DefaultDialer
}

func loadClientBase(url string, opt ...rpc.ClientOption) *ethclient.Client {
	// 通过infura连接到以太坊网络，构建连接client
	// API_KEY是在infura申请获得的，小狐狸钱包本身就是申请的infura所以可以查询到对应API_KEY
	// 4. 创建可配置的 RPC 客户端
	rpcClient, err := rpc.DialOptions(
		context.Background(),
		url,
		opt...,
	)
	if err != nil {
		panic(err)
	}
	// 5. 将 RPC 客户端包装为以太坊客户端
	return ethclient.NewClient(rpcClient)
}

// WaitTransactionReceipt 获取交易收据，支持重试机制
// client: 以太坊客户端
// maxRetries: 最大重试次数
// txHash: 交易哈希
// 返回值: 交易收据和错误信息
func WaitTransactionReceipt(client *ethclient.Client, maxRetries int, txHash common.Hash) (*types.Receipt, error) {
	if maxRetries <= 0 {
		return nil, fmt.Errorf("maxRetries must be greater than 0")
	}

	if client == nil {
		return nil, fmt.Errorf("ethclient cannot be nil")
	}

	timeLimit := 5

	ticker := time.NewTicker(time.Duration(timeLimit) * time.Second)
	defer ticker.Stop()

	log.Printf("开始监听交易: %s, 最大重试次数: %d", txHash.Hex(), maxRetries)

	for attempt := 1; attempt <= maxRetries; attempt++ {
		<-ticker.C

		// 检查交易状态
		_, isPending, err := client.TransactionByHash(context.Background(), txHash)
		if err != nil {
			// 如果是网络错误，继续重试
			if isNetworkError(err) {
				log.Printf("第 %d 次尝试: 网络错误, 交易: %s, 错误: %v", attempt, txHash.Hex(), err)
				continue
			}
			return nil, fmt.Errorf("获取交易状态失败: %w", err)
		}

		if isPending {
			log.Printf("第 %d 次尝试: 交易 %s 仍在处理中...", attempt, txHash.Hex())
			continue
		}

		// 交易已确认，获取收据
		receipt, err := client.TransactionReceipt(context.Background(), txHash)
		if err != nil {
			return nil, fmt.Errorf("获取交易收据失败: %w", err)
		}

		log.Printf("交易 %s 已确认! 耗时: %d 秒", txHash.Hex(), attempt*timeLimit)
		return receipt, nil
	}

	return nil, fmt.Errorf("交易 %s 在 %d 秒内未确认", txHash.Hex(), maxRetries)
}

func ShowReceipt(receipt *types.Receipt) {
	log.Printf("交易: %s, 状态: %v\n", receipt.TxHash.Hex(), receipt.Status == 1)
	log.Printf("区块哈希: %s\n", receipt.BlockHash.Hex())
	log.Printf("区块号: %d\n", receipt.BlockNumber)
	log.Printf("交易索引: %d\n", receipt.TransactionIndex)
	if receipt.ContractAddress.Hex() != EMPTY_ADDRESS {
		log.Println("部署的合约地址: ", receipt.ContractAddress.Hex())
	}
	log.Printf("logs(%d): \n %+v", len(receipt.Logs), receipt.Logs)
	if receipt.Status != 1 && receipt.ContractAddress.Hex() == EMPTY_ADDRESS {
		panic("交易失败")
	}
}

// isNetworkError 判断是否为网络错误（可重试的错误）
func isNetworkError(err error) bool {
	if err == nil {
		return false
	}
	// 常见的网络错误类型
	errorMsg := err.Error()
	return strings.Contains(errorMsg, "connection") ||
		strings.Contains(errorMsg, "timeout") ||
		strings.Contains(errorMsg, "network") ||
		strings.Contains(errorMsg, "EOF")
}

// HexToASCII 将十六进制字符串转换为 ASCII 字符串
func HexByteToASCII(hexBytes []byte) string {
	hexStr := common.BytesToHash(hexBytes).Hex()
	// 清理字符串：去除空格和前缀
	hexStr = strings.ReplaceAll(hexStr, " ", "")
	hexStr = strings.TrimPrefix(hexStr, "0x")
	hexStr = strings.TrimPrefix(hexStr, "0X")

	// 检查长度是否为偶数
	if len(hexStr)%2 != 0 {
		panic(fmt.Errorf("hex string length must be even"))
	}

	decoded, err := hex.DecodeString(hexStr)
	if err != nil {
		panic(err)
	}

	return string(decoded)
}
