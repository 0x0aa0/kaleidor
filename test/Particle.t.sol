// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Particle} from "../src/Particle.sol";
import {Strings} from "../src/utils/Strings.sol";

contract ParticleTest is Test{
    using Strings for uint256;

    Particle particle;

    function setUp() public {
        particle = new Particle(
            address(0),
            address(0),
            block.timestamp
        );
    }
 
    function xtestTenImages() public view {
        uint256 start = 1000;
        for(uint256 i = start; i < start + 10; i++){
            console2.log("<img src='", particle.getImage(i.toString()), "'></img>");
        }
    }
}
