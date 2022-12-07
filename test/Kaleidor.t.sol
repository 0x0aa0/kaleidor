// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Particle} from "../src/Particle.sol";
import {Proposal, Kaleidor} from "../src/Kaleidor.sol";
import {Event} from "../src/Event.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract KaleidorTest is Test{
    Kaleidor kaleidor;
    Particle particle;

    address feeReceiver = vm.addr(111);
    address alice = vm.addr(222);
    address bob = vm.addr(333);

    receive() external payable {}

    function setUp() public {
        kaleidor = new Kaleidor(feeReceiver, block.timestamp);
        particle = kaleidor.particle();

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(feeReceiver, "FEE");

        vm.warp(block.timestamp + 1);
    }

    function testMint() public {
        _mintToken(alice, "1");
        _mintToken(bob, "2");
    }

    function testCreate() public {
        _mintToken(alice, "1");
        _createProposal(alice);
    }

    function testVote() public {
        testMint();
        bytes32 _proposalHash = _createProposal(alice);
        _voteProposal(bob, _proposalHash);
    }

    function testExecute() public {
        testVote();
        vm.warp(block.timestamp + 30 days);
        address newEvent = kaleidor.execute();
        assertEq(address(newEvent).balance, 1 ether);
    }

    function _createProposal(address _user) internal returns(bytes32 _proposalHash) {
        Proposal memory prop = Proposal("TEST", "TEST", 1 ether);
        vm.prank(_user);
        _proposalHash = kaleidor.create(prop);
    }

    function _voteProposal(address _user, bytes32 _proposalHash) internal {
        vm.prank(_user);
        kaleidor.vote(_proposalHash);
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
