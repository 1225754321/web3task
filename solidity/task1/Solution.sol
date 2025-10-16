// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Solution {
    /**
     * @dev 反转字符串
     * @param str 要反转的字符串
     * @return 反转后的字符串
     */
    function reverseString(
        string memory str
    ) public pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        uint256 len = strBytes.length;
        for (uint256 i = 0; i < len / 2; i++) {
            (strBytes[i], strBytes[len - 1 - i]) = (
                strBytes[len - 1 - i],
                strBytes[i]
            );
        }
        return string(strBytes);
    }

    error InvalidRomanNumeralCharacter(bytes1 char);
    /**
     * @dev 将罗马数字转换为整数
     * @param s 罗马数字字符串
     * @return 转换后的整数
     * @notice 仅支持有效的罗马数字输入
     * @notice 遇到无效字符会抛出异常InvalidRomanNumeralCharacter(char)
     */
    function romanToInt(string memory s) public pure returns (uint256) {
        bytes memory strBytes = bytes(s);
        uint256 len = strBytes.length;
        uint256 res = 0;
        for (uint256 index = 0; index < len; index++) {
            if (strBytes[index] == "I") {
                if (index + 1 < len) {
                    if (strBytes[index + 1] == "V") {
                        res += 4;
                        index++;
                    } else if (strBytes[index + 1] == "X") {
                        res += 9;
                        index++;
                    } else {
                        res += 1;
                    }
                } else {
                    res += 1;
                }
            } else if (strBytes[index] == "V") {
                res += 5;
            } else if (strBytes[index] == "X") {
                if (index + 1 < len) {
                    if (strBytes[index + 1] == "L") {
                        res += 40;
                        index++;
                    } else if (strBytes[index + 1] == "C") {
                        res += 90;
                        index++;
                    } else {
                        res += 10;
                    }
                } else {
                    res += 10;
                }
            } else if (strBytes[index] == "L") {
                res += 50;
            } else if (strBytes[index] == "C") {
                if (index + 1 < len) {
                    if (strBytes[index + 1] == "D") {
                        res += 400;
                        index++;
                    } else if (strBytes[index + 1] == "M") {
                        res += 900;
                        index++;
                    } else {
                        res += 100;
                    }
                } else {
                    res += 100;
                }
            } else if (strBytes[index] == "D") {
                res += 500;
            } else if (strBytes[index] == "M") {
                res += 1000;
            } else {
                revert InvalidRomanNumeralCharacter(strBytes[index]);
            }
        }
        return res;
    }

    /**
     * @dev 将整数转换为罗马数字
     * @param num 要转换的整数
     * @return 转换后的罗马数字字符串
     * @notice 仅支持1到3999之间的整数
     */
    function intToRoman(uint256 num) public pure returns (string memory) {
        string[13] memory romans = [
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
        string memory res = "";
        for (uint256 i = 0; i < romans.length; i++) {
            while (num >= values[i]) {
                num -= values[i];
                res = string(abi.encodePacked(res, romans[i]));
            }
        }
        return res;
    }

    /**
     * @dev 合并两个已排序的数组
     * @param arr1 第一个数组
     * @param arr2 第二个数组
     * @return 合并后的新数组
     */
    function mergeSortedArrays(
        uint256[] memory arr1,
        uint256[] memory arr2
    ) public pure returns (uint256[] memory) {
        uint256 len1 = arr1.length;
        uint256 len2 = arr2.length;
        uint256[] memory res = new uint256[](len1 + len2);
        uint256 i = 0;
        uint256 j = 0;
        uint256 k = 0;
        while (i < len1 && j < len2) {
            if (arr1[i] < arr2[j]) {
                res[k++] = arr1[i++];
            } else {
                res[k++] = arr2[j++];
            }
        }
        while (i < len1) {
            res[k++] = arr1[i++];
        }
        while (j < len2) {
            res[k++] = arr2[j++];
        }
        return res;
    }

    /**
     * @dev 在已排序数组中进行二分查找
     * @param arr 要搜索的数组
     * @param target 要查找的目标值
     * @return 目标值的索引，如果未找到则返回-1
     */
    function binarySearch(
        uint256[] memory arr,
        uint256 target
    ) public pure returns (int256) {
        uint256 left = 0;
        uint256 right = arr.length - 1;
        while (left <= right) {
            uint256 mid = left + (right - left) / 2;
            if (arr[mid] == target) {
                return int256(mid);
            } else if (arr[mid] < target) {
                left = mid + 1;
            } else {
                if (mid == 0) break; // 防止 underflow
                right = mid - 1;
            }
        }
        return -1; // 未找到
    }
}
