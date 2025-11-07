package main

import (
	"fmt"
	"log"
	"strings"
	"task1/blocks"
	"task1/contracts"
	"task1/transactions"
	"task1/util"

	"github.com/spf13/cobra"
)

// init 初始化命令行标志和命令
func init() {
	// 设置根命令的持久标志
	rootCmd.PersistentFlags().StringP("env-file", "e", "", "指定环境变量文件路径 (默认: .env)")

	// 设置区块查询命令的标志 - 使用 Int64P 而不是 StringP 更合适
	blocksCmd.Flags().Int64P("id", "i", 0, "区块ID (必需)")
	blocksCmd.MarkFlagRequired("id")

	// 设置交易命令的标志
	transactionsCmd.Flags().StringP("to", "t", "", "接收地址 (必需)")
	transactionsCmd.Flags().Int64P("amount", "a", 0, "转账金额 (必需)")
	transactionsCmd.Flags().UintP("digits", "d", 0, "小数位数 (必需)")
	transactionsCmd.MarkFlagRequired("to")
	transactionsCmd.MarkFlagRequired("amount")
	transactionsCmd.MarkFlagRequired("digits")

	// 设置合约命令的标志
	contractsCmd.PersistentFlags().StringP("path", "p", "~/.task1_contractsAddress", "合约地址文件路径")
	contractsDeployCmd.Flags().BoolP("redeploy", "r", false, "(历史部署过的情况下)重新部署合约 (默认: false)")
	contractsCallCmd.Flags().StringP("method", "m", "", "调用合约的方法名 (必需) 只能是 'count' 或 'increment'")
	contractsCallCmd.MarkFlagRequired("method")

	// 将子命令添加到根命令
	rootCmd.AddCommand(blocksCmd)
	rootCmd.AddCommand(transactionsCmd)
	rootCmd.AddCommand(contractsCmd)
	rootCmd.AddCommand(envTemplateCmd)

	// 添加子命令的命令
	contractsCmd.AddCommand(contractsDeployCmd)
	contractsCmd.AddCommand(contractsCallCmd)
}

func main() {
	// 在执行命令前处理环境文件配置
	rootCmd.PersistentPreRunE = func(cmd *cobra.Command, args []string) error {
		envFile, err := cmd.Flags().GetString("env-file")
		if err != nil {
			return fmt.Errorf("获取环境文件参数错误: %w", err)
		}

		if envFile != "" {
			// 验证自定义环境文件
			if err := util.ValidateEnvFile(envFile); err != nil {
				return fmt.Errorf("环境文件验证失败: %w", err)
			}

			// 使用自定义环境文件初始化配置
			if err := util.InitConfig(envFile); err != nil {
				return fmt.Errorf("初始化配置失败: %w", err)
			}
			log.Printf("使用自定义环境文件: %s", envFile)
		}
		// 如果未指定自定义环境文件，使用默认配置（已在init中初始化）

		return nil
	}

	if err := rootCmd.Execute(); err != nil {
		log.Fatal("命令执行错误: ", err)
	}
}

var (
	// rootCmd 是根命令
	rootCmd = &cobra.Command{
		Use:   "task1",
		Short: "以太坊区块和交易操作工具",
		Long:  "一个用于查询以太坊区块信息和执行以太坊交易的命令行工具",
	}

	// blocksCmd 区块查询命令
	blocksCmd = &cobra.Command{
		Use:   "blocks",
		Short: "查询区块信息",
		Long:  "根据区块ID查询以太坊区块的详细信息",
		Run: func(cmd *cobra.Command, args []string) {
			// 获取并验证区块ID参数
			id, err := cmd.Flags().GetInt64("id")
			if err != nil {
				log.Fatal("获取区块ID参数错误: ", err)
			}
			if id <= 0 {
				log.Fatal("区块ID必须为正整数")
			}

			blocks.QueryById(id)
		},
	}

	// transactionsCmd 交易执行命令
	transactionsCmd = &cobra.Command{
		Use:   "transactions",
		Short: "执行以太坊交易",
		Long:  "执行以太坊转账交易，需要指定接收地址、金额和小数位数",
		Run: func(cmd *cobra.Command, args []string) {
			// 获取并验证接收地址
			to, err := cmd.Flags().GetString("to")
			if err != nil {
				log.Fatal("获取接收地址参数错误: ", err)
			}
			if to == "" {
				log.Fatal("接收地址不能为空")
			}

			// 获取并验证转账金额
			amount, err := cmd.Flags().GetInt64("amount")
			if err != nil {
				log.Fatal("获取金额参数错误: ", err)
			}
			if amount <= 0 {
				log.Fatal("转账金额必须为正数")
			}

			// 获取并验证小数位数
			digits, err := cmd.Flags().GetUint("digits")
			if err != nil {
				log.Fatal("获取小数位数参数错误: ", err)
			}

			transactions.Transactions(to, amount, digits)
		},
	}

	contractsCmd = &cobra.Command{
		Use:   "contracts",
		Short: "合约操作",
		Long:  "部署和调用智能合约",
		Run: func(cmd *cobra.Command, args []string) {
		},
	}

	contractsDeployCmd = &cobra.Command{
		Use:   "deploy",
		Short: "部署合约",
		Long:  "部署智能合约到以太坊网络",
		Run: func(cmd *cobra.Command, args []string) {
			path, err := cmd.Flags().GetString("path")
			if err != nil {
				log.Fatal("合约地址文件位置获取异常: ", err)
			}
			cs := contracts.NewContractService(path)
			defer cs.Close()
			redeploy, err := cmd.Flags().GetBool("redeploy")
			if err != nil {
				log.Fatal("获取重新部署参数异常: ", err)
			}
			if !redeploy && cs.Contracts != nil {
				log.Printf("已经加载了历史部署合约: %s, 如需重新部署请添加 --redeploy 参数\n", cs.Address)
				return
			}
			if redeploy {
				cs = cs.SetReDeploy()
			}
			cs.Deploy()
		},
	}
	contractsCallCmd = &cobra.Command{
		Use:   "call",
		Short: "调用合约",
		Long:  "调用已部署的智能合约",
		Run: func(cmd *cobra.Command, args []string) {
			method, err := cmd.Flags().GetString("method")
			if err != nil {
				log.Fatal("获取合约方法参数异常: ", err)
			}
			method = strings.ToLower(method)
			path, err := cmd.Flags().GetString("path")
			if err != nil {
				log.Fatal("合约地址文件位置获取异常: ", err)
			}
			cs := contracts.NewContractService(path)
			defer cs.Close()
			switch method {
			case "count":
				cs.Count()
			case "increment":
				cs.Increment()
			default:
				log.Fatal("无效的合约方法: ", method)
			}
		},
	}

	// envTemplateCmd 环境变量模板生成命令
	envTemplateCmd = &cobra.Command{
		Use:   "env-template",
		Short: "生成环境变量模板文件",
		Long:  "在当前目录下生成环境变量模板文件 (.env.template)",
		Run: func(cmd *cobra.Command, args []string) {
			// 生成环境变量模板文件
			if err := util.GenerateEnvTemplate(""); err != nil {
				log.Fatal("生成环境变量模板失败: ", err)
			}
			log.Println("环境变量模板文件已生成: .env.template")
		},
	}
)
