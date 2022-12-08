// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import {Particle} from "../src/Particle.sol";
import {Proposal, Kaleidor, IKaleidor} from "../src/Kaleidor.sol";
import {Event} from "../src/Event.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {IParticle} from "../src/interfaces/IParticle.sol";

contract KaleidorTest is Test{
    Kaleidor kaleidor;
    Particle particle;

    address feeReceiver = vm.addr(111);
    address alice = vm.addr(222);
    address bob = vm.addr(333);

    receive() external payable {}

    function setUp() public {
        vm.warp(block.timestamp + 1);
        kaleidor = new Kaleidor(feeReceiver, block.timestamp);
        particle = Particle(kaleidor.particle());

        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);

        vm.label(alice, "ALICE");
        vm.label(bob, "BOB");
        vm.label(feeReceiver, "FEE");
    }

    function testMint() public {
        _mintToken(alice, "1");
        _mintToken(bob, "2");
    }

    function testMintNotStarted() public {
        uint256 price = _getPrice();
        vm.warp(block.timestamp - 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IParticle.NotStarted.selector));
        particle.mint{value: price}("1");
    }

    function testMintAlreadyDiscovered() public {
        _mintToken(alice, "1");
        uint256 price = _getPrice();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IParticle.AlreadyDiscovered.selector));
        particle.mint{value: price}("1");
    }

    function testMintUnderpaid() public {
        uint256 price = _getPrice() - 1;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IParticle.Underpaid.selector));
        particle.mint{value: price}("1");
    }

    function testMintRefund() public {
        uint256 price = _getPrice();
        vm.prank(alice);
        particle.mint{value: price + 1 ether}("1");

        assertEq(alice.balance, 100 ether - price);
        assertEq(feeReceiver.balance, price / 20);
        assertEq(address(kaleidor).balance, price - (price / 20));
    }

    function testURINotDiscovered() public {
        vm.expectRevert(abi.encodeWithSelector(IParticle.NotDiscovered.selector));
        particle.tokenURI(0);
    }

    function testTransfer() public {
        uint256 id = _mintToken(alice, "1");
        vm.prank(alice);
        particle.transferFrom(alice, bob, id);
    }

    function testCreate() public {
        _mintToken(alice, "1");
        bytes32 _proposalHash = _createProposal(alice);

        (string memory title, string memory description, uint256 amount) = kaleidor.proposals(_proposalHash);
        
        assertEq(title, "TEST");
        assertEq(description, "TEST");
        assertEq(amount, 1 ether);
        assertEq(kaleidor.proposalVotes(_proposalHash), 1);
        assertEq(kaleidor.topProposal(), _proposalHash);
        assertEq(kaleidor.userVote(alice), _proposalHash);
    }

    function testVote() public {
        testMint();
        bytes32 _proposalHash = _createProposal(alice);
        _voteProposal(bob, _proposalHash);

        assertEq(kaleidor.proposalVotes(_proposalHash), 2);
        assertEq(kaleidor.topProposal(), _proposalHash);
        assertEq(kaleidor.userVote(alice), _proposalHash);
        assertEq(kaleidor.userVote(bob), _proposalHash);
    }

    function testVoteInvalidProposal() public {
        (bytes32 _proposalHash, ) = _executeProposal(alice);
        vm.expectRevert(abi.encodeWithSelector(IKaleidor.InvalidProposal.selector));
        _voteProposal(bob, bytes32(0));
        vm.expectRevert(abi.encodeWithSelector(IKaleidor.InvalidProposal.selector));
        _voteProposal(bob, _proposalHash);
    }

    function testVoteNoTokens() public {
        vm.expectRevert(abi.encodeWithSelector(IKaleidor.NoTokens.selector));
        _voteProposal(alice, keccak256(""));
    }

    function testChangeVote() public {
        testMint();
        bytes32 alice_proposalHash = _createProposal(alice);
        bytes32 bob_proposalHash = _createProposal(bob);

        _voteProposal(alice, bob_proposalHash);

        assertEq(kaleidor.proposalVotes(bob_proposalHash), 2);
        assertEq(kaleidor.proposalVotes(alice_proposalHash), 0);
        assertEq(kaleidor.topProposal(), bob_proposalHash);
        assertEq(kaleidor.userVote(alice), bob_proposalHash);
        assertEq(kaleidor.userVote(bob), bob_proposalHash);
    }

    function testTransferVote() public {
        _mintToken(alice, "1");
        bytes32 _proposalHash = _createProposal(alice);

        uint256 id = _mintToken(bob, "2");
        _voteProposal(bob, _proposalHash);
        vm.prank(bob);
        particle.transferFrom(bob, feeReceiver, id);


        assertEq(kaleidor.proposalVotes(_proposalHash), 1);

        assertEq(kaleidor.userVote(alice), _proposalHash);
        assertEq(kaleidor.userVote(bob), bytes32(0));
    }

    function testVoteSurpass() public {
        _mintToken(alice, "1");
        bytes32 alice_proposalHash = _createProposal(alice);
        assertEq(kaleidor.topProposal(), alice_proposalHash);

        _mintToken(bob, "2");
        bytes32 bob_proposalHash = _createProposal(bob);
        assertEq(kaleidor.topProposal(), alice_proposalHash);

        _mintToken(bob, "3");
        _voteProposal(bob, bob_proposalHash);
        assertEq(kaleidor.topProposal(), bob_proposalHash);
    }

    function testUnvote() public {
        _mintToken(alice, "1");
        bytes32 _proposalHash = _createProposal(alice);
        _unvoteProposal(alice);

        assertEq(kaleidor.proposalVotes(_proposalHash), 0);
        assertEq(kaleidor.userVote(alice), bytes32(0));
    }

    function testUnvoteNotAuthorized() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IKaleidor.NotAuthorized.selector));
        kaleidor.unvote(alice);
    }

    function testExecute() public {
        (bytes32 _proposalHash, address newEvent) = _executeProposal(alice);

        assertEq(kaleidor.topProposal(), bytes32(0));
        assertEq(kaleidor.proposalVotes(_proposalHash), 0);
        assertEq(kaleidor.executed(_proposalHash), true);
        assertEq(kaleidor.currentEvent(), newEvent);
        assertEq(newEvent.balance, 1 ether);
    }

    function testExecuteTimeNotElapsed() public {
        _mintToken(alice, "1");
        vm.deal(address(kaleidor), 1 ether);
        bytes32 _proposalHash = _createProposal(alice);
        vm.warp(block.timestamp + 30 days - 1);
        vm.expectRevert(abi.encodeWithSelector(IKaleidor.TimeNotElapsed.selector));
        kaleidor.execute();
    }

    function _mintToken(address _user, string memory _signal) internal returns(uint256 id) {
        uint256 price = _getPrice();
        vm.prank(_user);
        id = particle.mint{value: price}(_signal);
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

    function _unvoteProposal(address _user) internal {
        vm.prank(_user);
        kaleidor.unvote(_user);
    }

    function _executeProposal(address _user) internal returns(bytes32 _proposalHash, address newEvent){
        _mintToken(_user, "EXECUTE");
        vm.deal(address(kaleidor), 1 ether);
        _proposalHash = _createProposal(_user);
        vm.warp(block.timestamp + 30 days);
        newEvent = kaleidor.execute();
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
