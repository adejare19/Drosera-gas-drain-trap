// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Drosera GasDrainTrap
/// @notice A Foundry-ready Trap that adheres to Drosera's required interface:

/// HOW TO USE
/// 1) Edit the WATCHED_ADDRESSES list below to the addresses you want to monitor.
/// 2) Optionally tweak thresholds (MIN_DROP_WEI, MIN_DROP_BPS, MIN_BLOCKS_WINDOW).
/// 3) Deploy. The Drosera operator will periodically call collect() and feed the
///    returned snapshots into shouldRespond(data) to decide whether to trigger.
///
/// Signal logic
/// - If ANY watched address experiences a balance drop greater than MIN_DROP_WEI
///   AND a relative drop >= MIN_DROP_BPS (basis points) between the most recent
///   two snapshots (separated by at least MIN_BLOCKS_WINDOW blocks), the trap
///   returns true with an encoded payload describing the offender and amounts.

interface IDroseraTrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(
        bytes[] calldata data
    ) external pure returns (bool, bytes memory);
}

library GasDrainCodec {
    struct Snapshot {
        uint256 blockNumber;
        uint256 timestamp;
        address[] addrs;
        uint256[] balances;
    }

    function encode(
        uint256 blockNumber,
        uint256 timestamp,
        address[] memory addrs,
        uint256[] memory balances
    ) internal pure returns (bytes memory) {
        return abi.encode(blockNumber, timestamp, addrs, balances);
    }

    function decode(
        bytes memory blob
    ) internal pure returns (Snapshot memory s) {
        (s.blockNumber, s.timestamp, s.addrs, s.balances) = abi.decode(
            blob,
            (uint256, uint256, address[], uint256[])
        );
    }
}

contract GasDrainTrap is IDroseraTrap {
    using GasDrainCodec for bytes;

    // ==========================
    // ===== CONFIG (EDIT) ======
    // ==========================

    address[] private _WATCHED_ADDRESSES = [
        // TODO: replace placeholders
        address(0x000000000000000000000000000000000000dEaD)
    ];

    // Absolute minimum drop between two samples to consider it a "drain" (in wei)
    uint256 public constant MIN_DROP_WEI = 0.05 ether;

    uint256 public constant MIN_DROP_BPS = 2000; // EDIT as needed

    uint256 public constant MIN_BLOCKS_WINDOW = 2; // EDIT as needed

    // ==========================
    // ====== INTERFACE =========
    // ==========================

    /// @notice Collect a snapshot of balances for all watched addresses.
    /// @dev Off-chain operator calls this periodically and stores the bytes.
    function collect() external view override returns (bytes memory) {
        uint256 n = _WATCHED_ADDRESSES.length;
        address[] memory addrs = new address[](n);
        uint256[] memory bals = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            address a = _WATCHED_ADDRESSES[i];
            addrs[i] = a;
            bals[i] = a.balance;
        }
        return GasDrainCodec.encode(block.number, block.timestamp, addrs, bals);
    }

    /// @notice Decide whether to trigger based on the most recent snapshots.
    /// @param data Array of encoded snapshots returned by collect().
    /// @return should True if criteria are met; payload Encoded details.
    function shouldRespond(
        bytes[] calldata data
    ) external pure override returns (bool should, bytes memory payload) {
        if (data.length < 2) {
            return (false, abi.encode("NEED_MORE_SAMPLES"));
        }

        GasDrainCodec.Snapshot memory prev = GasDrainCodec.decode(
            data[data.length - 2]
        );
        GasDrainCodec.Snapshot memory curr = GasDrainCodec.decode(
            data[data.length - 1]
        );

        if (prev.addrs.length != curr.addrs.length || prev.addrs.length == 0) {
            return (false, abi.encode("BAD_SNAPSHOT_DIMENSIONS"));
        }

        if (
            curr.blockNumber <= prev.blockNumber ||
            (curr.blockNumber - prev.blockNumber) < MIN_BLOCKS_WINDOW
        ) {
            return (false, abi.encode("WINDOW_TOO_SMALL"));
        }

        for (uint256 i = 0; i < curr.addrs.length; i++) {
            if (curr.addrs[i] != prev.addrs[i]) {
                continue;
            }
            uint256 bPrev = prev.balances[i];
            uint256 bCurr = curr.balances[i];
            if (bCurr >= bPrev) continue;

            uint256 drop = bPrev - bCurr;

            if (drop < MIN_DROP_WEI) continue;

            if (bPrev == 0) continue;
            uint256 dropBps = (drop * 10_000) / bPrev;
            if (dropBps < MIN_DROP_BPS) continue;

            payload = abi.encode(
                curr.addrs[i],
                bPrev,
                bCurr,
                drop,
                prev.blockNumber,
                curr.blockNumber,
                prev.timestamp,
                curr.timestamp
            );
            return (true, payload);
        }

        return (false, abi.encode("NO_DRAIN"));
    }

    function watched() external view returns (address[] memory) {
        return _WATCHED_ADDRESSES;
    }
}
