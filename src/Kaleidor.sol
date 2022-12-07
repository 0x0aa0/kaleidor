// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Event} from "./Event.sol";
import {Particle} from "./Particle.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

contract Kaleidor is IKaleidor{
    using ClonesWithImmutableArgs for address;

    Particle public immutable particle;
    address public immutable eventImplementation;

    bytes32 public topProposal;
    uint256 public nextEvent;
    address public currentEvent;

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => bytes32) public userVote;
    mapping(bytes32 => uint256) public proposalVotes;

    constructor(
        address _feeReceiver,
        uint256 _startTime
    ) {
        particle = new Particle(
            address(this),
            _feeReceiver,
            _startTime
        );
        eventImplementation = address(new Event(particle));
        nextEvent = _startTime + 30 days;
    }

    receive() external payable {}

    function create(Proposal memory _proposal) external returns(bytes32 _proposalHash) {
        _proposalHash = keccak256(abi.encode(_proposal, msg.sender));
        proposals[_proposalHash] = _proposal;
        _updateVotes(_proposalHash);
    }

    function vote(bytes32 _proposalHash) external {
        _updateVotes(_proposalHash);
    }

    function unvote(address _user) external {
        if(_user != msg.sender){
            require(msg.sender == address(particle));
        }

        bytes32 prevVote = userVote[msg.sender];

        if(proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= particle.balanceOf(msg.sender);
        }

        userVote[msg.sender] = bytes32(0);
    }

    function execute() external returns (address newEvent) {
        if(block.timestamp < nextEvent) revert TimeNotElapsed();

        uint256 amount = proposals[topProposal].amount;

        nextEvent = block.timestamp + 30 days;
        newEvent = eventImplementation.clone(abi.encode(nextEvent));

        proposalVotes[topProposal] = 0;
        topProposal = bytes32(0);
        currentEvent = newEvent;

        SafeTransferLib.safeTransferETH(newEvent, amount);
    }

    function _updateVotes(bytes32 _proposalHash) internal {
        uint256 balance = particle.balanceOf(msg.sender);
        if(balance == 0) revert NoTokens();

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0) && proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= balance;
        } 

        userVote[msg.sender] = _proposalHash;
        proposalVotes[_proposalHash] += balance;

        if (proposalVotes[_proposalHash] > proposalVotes[topProposal]){
            topProposal = _proposalHash;
        }
    }
}

