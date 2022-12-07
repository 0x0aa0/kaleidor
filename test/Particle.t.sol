// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Particle} from "../src/Particle.sol";
import {Strings} from "../src/utils/Strings.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract ParticleTest is Test{
    using Strings for uint256;

    Particle particle;

    address alice = vm.addr(222);
    address bob = vm.addr(333);

    function setUp() public {
        particle = new Particle(
            address(0),
            address(0),
            block.timestamp
        );

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
    }

    function xtestPricing() public {
        console.log(_getPrice());
        vm.warp(block.timestamp + 1 days);
        console.log(_getPrice());
        _mintToken(alice, "1");
        console.log(_getPrice());
        _mintToken(alice, "2");
        console.log(_getPrice());
        vm.warp(block.timestamp + 1 days);
        console.log(_getPrice());
    }
 
    function xtestTenImages() public view {
        uint256 start = 1000;
        for(uint256 i = start; i < start + 10; i++){
            console2.log("<img src='", particle.getImage(i.toString()), "'></img>");
        }
    }

    function _mintToken(address _user, string memory _signal) internal {
        uint256 price = _getPrice();
        vm.prank(_user);
        particle.mint{value: price}(_signal);
    }

    function _getPrice() internal view returns(uint256 price){
        price = particle.getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - particle.startTime()
            ), 
            particle.totalSold()
        );
    }
}
