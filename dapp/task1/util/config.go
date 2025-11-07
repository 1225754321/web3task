package util

import (
	_ "embed"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"

	"github.com/spf13/viper"
	"github.com/valyala/fasttemplate"
)

//go:embed .env.template
var ENV_TEMPLATE string

var (
	// envFilePath 存储自定义环境文件路径
	envFilePath string
)

// InitConfig 初始化配置，支持自定义环境文件路径
func InitConfig(customEnvFile string) error {
	viper.Reset()

	if customEnvFile != "" {
		// 使用自定义环境文件
		viper.SetConfigFile(customEnvFile)
		envFilePath = customEnvFile
	} else {
		// 使用默认配置
		viper.SetConfigName(".env")
		viper.SetConfigType("env")
		viper.AddConfigPath(findFileDirFrom(5, ".env"))
		envFilePath = ""
	}

	err := viper.ReadInConfig()
	if err != nil {
		if errors.As(err, &viper.ConfigFileNotFoundError{}) {
			log.Printf("配置文件未找到, 请在命令运行目录添加: .env 文件, 文件格式模板如下:\n\n```.env\n%s\n```\n\n", ENV_TEMPLATE)
		}
		return fmt.Errorf("fatal error config file: %w", err)
	}

	// 实时监听修改, 并更新配置
	go viper.WatchConfig()
	return nil
}

// ReloadConfig 重新加载环境变量配置
func ReloadConfig() error {
	if envFilePath != "" {
		viper.SetConfigFile(envFilePath)
	} else {
		viper.SetConfigName(".env")
		viper.SetConfigType("env")
		viper.AddConfigPath(findFileDirFrom(5, ".env"))
	}

	err := viper.ReadInConfig()
	if err != nil {
		return fmt.Errorf("重新加载配置文件失败: %w", err)
	}
	return nil
}

// ValidateEnvFile 验证环境文件是否存在且可读
func ValidateEnvFile(filePath string) error {
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("环境文件不存在: %s", filePath)
		}
		return fmt.Errorf("无法访问环境文件: %w", err)
	}

	if fileInfo.IsDir() {
		return fmt.Errorf("指定的路径是目录而不是文件: %s", filePath)
	}

	// 检查文件是否可读
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("环境文件不可读: %w", err)
	}
	file.Close()

	return nil
}

func init() {
	// 保持向后兼容性，使用默认配置初始化
	if err := InitConfig(""); err != nil {
		panic(err)
	}
}

func LoadEnv(in string) (out string) {
	t := fasttemplate.New(in, "<", ">")
	out = t.ExecuteFuncString(func(w io.Writer, tag string) (int, error) {
		return w.Write([]byte(viper.GetString(tag)))
	})
	return
}

// findFileDirFrom 从指定目录开始查找包含file文件的最近父目录
// maxLevel: 最大向上搜索的层数，0表示无限制
// file: 要查找的文件名
func findFileDirFrom(maxLevel int, file string) string {
	dir, err := os.Getwd()
	if err != nil {
		log.Printf("获取当前工作目录失败: %+v\n", err)
		return ""
	}

	level := 0

	for {
		// 检查当前目录是否存在.env文件
		envPath := filepath.Join(dir, file)
		if _, err := os.Stat(envPath); err == nil {
			return dir
		} else if !os.IsNotExist(err) {
			log.Printf("检查.env文件失败: %+v\n", err)
			return ""
		}

		// 检查是否达到最大搜索层数
		if maxLevel > 0 && level >= maxLevel {
			log.Printf("在%d层目录内未找到.env文件", maxLevel)
			return ""
		}

		// 获取父目录
		parentDir := filepath.Dir(dir)

		// 如果已经到达根目录，停止遍历
		if parentDir == dir {
			log.Printf("在目录路径中未找到.env文件\n")
			return ""
		}
		dir = parentDir
		level++
	}
}

// GenerateEnvTemplate 生成环境变量模板文件
func GenerateEnvTemplate(outputPath string) error {
	// 如果未指定输出路径，使用当前目录下的 .env.template
	if outputPath == "" {
		outputPath = ".env.template"
	}

	// 检查文件是否已存在
	if _, err := os.Stat(outputPath); err == nil {
		return fmt.Errorf("环境变量模板文件已存在: %s", outputPath)
	}

	// 创建并写入模板文件
	file, err := os.Create(outputPath)
	if err != nil {
		return fmt.Errorf("创建环境变量模板文件失败: %w", err)
	}
	defer file.Close()

	// 写入模板内容
	_, err = file.WriteString(ENV_TEMPLATE)
	if err != nil {
		return fmt.Errorf("写入环境变量模板文件失败: %w", err)
	}

	return nil
}
