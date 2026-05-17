// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GasBenchmark} from "../src/GasBenchmark.sol";

contract GasBenchmarkTest is Test {
    GasBenchmark public benchmark;

    function setUp() public {
        benchmark = new GasBenchmark();
    }

    function testHashPairSolidityAndAssemblyReturnSameResult() public view {
        bytes32 a = keccak256("gold");
        bytes32 b = keccak256("vault");

        assertEq(benchmark.hashPairSolidity(a, b), benchmark.hashPairAssembly(a, b));
    }

    function testSumArraySolidityAndAssemblyReturnSameResult() public view {
        uint256[] memory arr = new uint256[](5);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        arr[3] = 4;
        arr[4] = 5;

        assertEq(benchmark.sumArraySolidity(arr), benchmark.sumArrayAssembly(arr));
    }

    function testSumEmptyArrayReturnsZero() public view {
        uint256[] memory arr = new uint256[](0);

        assertEq(benchmark.sumArraySolidity(arr), 0);
        assertEq(benchmark.sumArrayAssembly(arr), 0);
    }

    function testMemcpySolidityAndAssemblyReturnSameBytes() public view {
        bytes memory data = abi.encodePacked("GoldVault DAO");

        bytes memory solidityResult = benchmark.memcpySolidity(data);
        bytes memory assemblyResult = benchmark.memcpyAssembly(data);

        assertEq(solidityResult, assemblyResult);
    }

    function testMemcpyEmptyBytes() public view {
        bytes memory data = "";

        assertEq(benchmark.memcpySolidity(data), data);
        assertEq(benchmark.memcpyAssembly(data), data);
    }

    function testMinSolidityAndAssemblyReturnSameResult() public view {
        assertEq(benchmark.minSolidity(10, 20), 10);
        assertEq(benchmark.minAssembly(10, 20), 10);

        assertEq(benchmark.minSolidity(20, 10), 10);
        assertEq(benchmark.minAssembly(20, 10), 10);

        assertEq(benchmark.minSolidity(10, 10), 10);
        assertEq(benchmark.minAssembly(10, 10), 10);
    }

    function testMaxSolidityAndAssemblyReturnSameResult() public view {
        assertEq(benchmark.maxSolidity(10, 20), 20);
        assertEq(benchmark.maxAssembly(10, 20), 20);

        assertEq(benchmark.maxSolidity(20, 10), 20);
        assertEq(benchmark.maxAssembly(20, 10), 20);

        assertEq(benchmark.maxSolidity(10, 10), 10);
        assertEq(benchmark.maxAssembly(10, 10), 10);
    }

    function testExtractAddressSolidityAndAssemblyReturnSameResult() public view {
        address expected = address(0x1234567890123456789012345678901234567890);
        bytes32 packed = bytes32(uint256(uint160(expected)));

        assertEq(benchmark.extractAddressSolidity(packed), benchmark.extractAddressAssembly(packed));

        assertEq(benchmark.extractAddressAssembly(packed), expected);
    }

    function testFuzzMinAssemblyMatchesSolidity(uint256 a, uint256 b) public view {
        assertEq(benchmark.minAssembly(a, b), benchmark.minSolidity(a, b));
    }

    function testFuzzMaxAssemblyMatchesSolidity(uint256 a, uint256 b) public view {
        assertEq(benchmark.maxAssembly(a, b), benchmark.maxSolidity(a, b));
    }

    function testFuzzHashPairAssemblyMatchesSolidity(bytes32 a, bytes32 b) public view {
        assertEq(benchmark.hashPairAssembly(a, b), benchmark.hashPairSolidity(a, b));
    }

    function testFuzzExtractAddressAssemblyMatchesSolidity(bytes32 packed) public view {
        assertEq(benchmark.extractAddressAssembly(packed), benchmark.extractAddressSolidity(packed));
    }
}
