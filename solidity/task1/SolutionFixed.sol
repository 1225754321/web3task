// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Solution {
    /**
     * @dev 反转字符串
     * @param str 要反转的字符串
     * @return 反转后的字符串
     * @notice 优化前：使用元组交换，消耗更多 gas 优化后：使用临时变量进行单个赋值，减少 gas 消耗
     */
    function reverseString(
        string memory str
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint256 len = strBytes.length;
        for (uint256 i = 0; i < len / 2; i++) {
            bytes1 temp = strBytes[i];
            strBytes[i] = strBytes[len - 1 - i];
            strBytes[len - 1 - i] = temp;
        }
        return string(strBytes);
    }

    error InvalidRomanNumeralCharacter(bytes1 char);
    error InvalidRomanNumeralCharacter2(bytes2 char);
    /**
     * @dev 将罗马数字转换为整数
     * @param s 罗马数字字符串
     * @return 转换后的整数
     * @notice 仅支持有效的罗马数字输入
     * @notice 遇到无效字符会抛出异常InvalidRomanNumeralCharacter(char)
     * @notice 优化前：嵌套过深且重复代码较多，优化后：使用辅助函数简化逻辑，提升可读性和维护性
     */
    function romanToInt(string memory s) public pure returns (uint256) {
        bytes memory roman = bytes(s);
        uint256 len = roman.length;
        uint256 result = 0;

        for (uint256 i = 0; i < len; i++) {
            uint256 current = _getRomanValue(roman[i]);
            if (current == 0) {
                revert InvalidRomanNumeralCharacter(roman[i]);
            }

            if (i + 1 < len) {
                bytes2 pair = bytes2(roman[i]) | (bytes2(roman[i + 1]) >> 8);
                uint256 next = _getRomanValue2(pair);
                if (current < next) {
                    result += next - current;
                    i++; // Skip next character
                }
            }
            result += current;
        }

        return result;
    }

    function _getRomanValue(bytes1 char) private pure returns (uint256) {
        if (char == "I") return 1;
        if (char == "V") return 5;
        if (char == "X") return 10;
        if (char == "L") return 50;
        if (char == "C") return 100;
        if (char == "D") return 500;
        if (char == "M") return 1000;
        return 0;
    }

    function _getRomanValue2(bytes2 char) private pure returns (uint256) {
        if (char == "IV") return 4;
        if (char == "IX") return 9;
        if (char == "XL") return 40;
        if (char == "XC") return 90;
        if (char == "CD") return 400;
        if (char == "CM") return 900;
        return 0;
    }

    /**
     * @dev 将整数转换为罗马数字
     * @param num 要转换的整数
     * @return 转换后的罗马数字字符串
     * @notice 仅支持1到3999之间的整数
     * @notice 优化前：使用元组交换，消耗更多 gas 优化后：使用临时变量进行单个赋值，减少 gas 消耗
     */
    function intToRoman(uint256 num) public pure returns (string memory) {
        require(num > 0 && num < 4000, "Number must be between 1 and 3999");

        string[13] memory symbols = [
            "M",
            "CM",
            "D",
            "CD",
            "C",
            "XC",
            "L",
            "XL",
            "X",
            "IX",
            "V",
            "IV",
            "I"
        ];
        uint256[13] memory values = [
            uint256(1000),
            900,
            500,
            400,
            100,
            90,
            50,
            40,
            10,
            9,
            5,
            4,
            1
        ];

        // 预估算最大长度（最长情况：MMMDCCCLXXXVIII = 3888，15个字符）
        bytes memory resultBytes = new bytes(15);
        uint256 resultIndex = 0;
        uint256 remaining = num;

        for (uint256 i = 0; i < values.length; i++) {
            while (remaining >= values[i]) {
                remaining -= values[i];
                bytes memory symbolBytes = bytes(symbols[i]);
                for (uint256 j = 0; j < symbolBytes.length; j++) {
                    resultBytes[resultIndex++] = symbolBytes[j];
                }
            }
        }

        // 截断到实际使用的长度
        bytes memory finalResult = new bytes(resultIndex);
        for (uint256 i = 0; i < resultIndex; i++) {
            finalResult[i] = resultBytes[i];
        }

        return string(finalResult);
    }

    /**
     * @dev 合并两个已排序的数组
     * @param arr1 第一个数组
     * @param arr2 第二个数组
     * @return 合并后的新数组
     * @notice 优化前：未处理空数组情况，可能导致错误 优化后：添加空数组处理逻辑
     */
    function mergeSortedArrays(
        uint256[] memory arr1,
        uint256[] memory arr2
    ) public pure returns (uint256[] memory) {
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;

        // 处理空数组的情况
        if (len1 == 0) return arr2;
        if (len2 == 0) return arr1;

        uint256[] memory result = new uint256[](len1 + len2);
        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;

        while (i < len1 && j < len2) {
            if (arr1[i] <= arr2[j]) {
                result[k++] = arr1[i++];
            } else {
                result[k++] = arr2[j++];
            }
        }

        // 复制剩余元素
        while (i < len1) {
            result[k++] = arr1[i++];
        }
        while (j < len2) {
            result[k++] = arr2[j++];
        }

        return result;
    }

    /**
     * @dev 在已排序数组中进行二分查找
     * @param arr 要搜索的数组
     * @param target 要查找的目标值
     * @return 目标值的索引，如果未找到则返回-1
     * @notice 优化后：加强 underflow 保护，改进注释
     */
    function binarySearch(
        uint256[] memory arr,
        uint256 target
    ) public pure returns (int256) {
        uint256 length = arr.length;
        if (length == 0) return -1;

        uint256 left = 0;
        uint256 right = length - 1;

        while (left <= right) {
            // 使用无符号整数安全计算中间值
            uint256 mid = left + (right - left) / 2;

            if (arr[mid] == target) {
                return int256(mid);
            }

            if (arr[mid] < target) {
                left = mid + 1;
            } else {
                // 安全处理：避免 underflow
                if (mid == 0) {
                    break;
                }
                right = mid - 1;
            }
        }

        return -1;
    }
}
