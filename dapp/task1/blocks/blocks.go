package blocks

import (
	"context"
	"log"
	"math/big"
	"task1/util"
)

// 使用 ethclient 连接到 Sepolia 测试网络。
// 实现查询指定区块号的区块信息，包括区块的哈希、时间戳、交易数量等。
// 输出查询结果到控制台。
func QueryById(id int64) {
	client := util.LoadClient()
	block, err := client.BlockByNumber(context.Background(), big.NewInt(id))
	if err != nil {
		log.Fatal("区块查询失败: ", err)
	}
	log.Printf("区块 %d 的哈希: %s\n", id, block.Hash().Hex())
	log.Printf("区块 %d 的时间戳: %d\n", id, block.Time())
	log.Printf("区块 %d 的交易数量: %d\n", id, len(block.Transactions()))
}
