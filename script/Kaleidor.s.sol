// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import {Kaleidor} from "../src/Kaleidor.sol";


contract Deploy is Script{

    Kaleidor kaleidor;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        kaleidor = new Kaleidor(msg.sender, block.timestamp);
        vm.stopBroadcast();
    }
}