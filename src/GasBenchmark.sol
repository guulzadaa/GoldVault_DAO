// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract GasBenchmark {
    // ─── Hash Pair ───────────────────────────────────────────────────────────

    function hashPairSolidity(bytes32 a, bytes32 b) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(a, b));
    }

    function hashPairAssembly(bytes32 a, bytes32 b) external pure returns (bytes32 result) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            result := keccak256(0x00, 0x40)
        }
    }

    // ─── Array Sum ───────────────────────────────────────────────────────────

    function sumArraySolidity(uint256[] calldata arr) external pure returns (uint256 total) {
        uint256 len = arr.length;
        for (uint256 i; i < len; ++i) {
            total += arr[i];
        }
    }

    function sumArrayAssembly(uint256[] calldata arr) external pure returns (uint256 total) {
        assembly {
            let len := arr.length
            let offset := arr.offset
            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                total := add(total, calldataload(add(offset, mul(i, 0x20))))
            }
        }
    }

    // ─── Memory Copy ─────────────────────────────────────────────────────────

    function memcpySolidity(bytes memory src) external pure returns (bytes memory dst) {
        uint256 len = src.length;
        dst = new bytes(len);
        for (uint256 i; i < len; ++i) {
            dst[i] = src[i];
        }
    }

    function memcpyAssembly(bytes memory src) external pure returns (bytes memory dst) {
        uint256 len = src.length;
        dst = new bytes(len);
        assembly {
            let srcPtr := add(src, 0x20)
            let dstPtr := add(dst, 0x20)
            let words := div(add(len, 31), 32)
            for { let i := 0 } lt(i, words) { i := add(i, 1) } {
                mstore(add(dstPtr, mul(i, 0x20)), mload(add(srcPtr, mul(i, 0x20))))
            }
        }
    }

    // ─── Min / Max ───────────────────────────────────────────────────────────

    function minSolidity(uint256 a, uint256 b) external pure returns (uint256) {
        return a < b ? a : b;
    }

    function minAssembly(uint256 a, uint256 b) external pure returns (uint256 result) {
        assembly {
            result := xor(b, mul(xor(a, b), lt(a, b)))
        }
    }

    function maxSolidity(uint256 a, uint256 b) external pure returns (uint256) {
        return a > b ? a : b;
    }

    function maxAssembly(uint256 a, uint256 b) external pure returns (uint256 result) {
        assembly {
            result := xor(a, mul(xor(a, b), gt(b, a)))
        }
    }

    // ─── Packed Address Extraction ────────────────────────────────────────────

    function extractAddressSolidity(bytes32 packed) external pure returns (address) {
        return address(uint160(uint256(packed)));
    }

    function extractAddressAssembly(bytes32 packed) external pure returns (address result) {
        assembly {
            result := and(packed, 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}
