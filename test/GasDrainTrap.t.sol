// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GasDrainTrap.sol";

/// @title GasDrainTrap.t.sol
/// @notice Basic Foundry tests for GasDrainTrap
contract GasDrainTrapTest is Test {
    GasDrainTrap trap;

    function setUp() public {
        trap = new GasDrainTrap();
    }

    function testCollectReturnsSnapshot() public view {
        bytes memory data = trap.collect();
        assertGt(data.length, 0, "collect() should return encoded snapshot");
    }

    function testShouldRespondNeedsMoreSamples() public view {
        bytes[] memory samples = new bytes[](1);
        samples[0] = trap.collect();
        (bool shouldRespond, bytes memory payload) = trap.shouldRespond(samples);
        assertFalse(shouldRespond, "With only one sample, shouldRespond must be false");
        assertGt(payload.length, 0, "payload must explain why");
    }

    function testShouldRespondNoDrain() public {
        // Two identical snapshots should not trigger
        bytes[] memory samples = new bytes[](2);
        samples[0] = trap.collect();
        samples[1] = trap.collect();
        (bool shouldRespond, bytes memory payload) = trap.shouldRespond(samples);
        assertFalse(shouldRespond, "No balance drop, shouldRespond must be false");
        assertGt(payload.length, 0, "payload must explain reason");
    }

    function testWatchedAddressesExposed() public view {
        address[] memory addrs = trap.watched();
        assertGt(addrs.length, 0, "watched() should return at least one address");
    }


}
