// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Event} from "./Event.sol";
import {Particle} from "./Particle.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

struct Proposal{
    string title;
    string description;
    uint256 amount;
}

contract Kaleidor {
    using ClonesWithImmutableArgs for address;

    Particle immutable particle;
    address immutable eventImplementation;

    bytes32 public topProposal;
    uint256 public nextEvent;
    address public currentEvent;

    mapping(bytes32 => Proposal) proposals;
    mapping(address => bytes32) userVote;
    mapping(bytes32 => uint256) proposalVotes;

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

    function create(Proposal memory _proposal) external {
        bytes32 _proposalHash = keccak256(abi.encode(_proposal));
        proposals[_proposalHash] = _proposal;
        _updateVotes(_proposalHash);
    }

    function vote(bytes32 _proposalHash) external {
        _updateVotes(_proposalHash);
    }

    function unvote() external {
        bytes32 prevVote = userVote[msg.sender];

        if(proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= particle.balanceOf(msg.sender);
        }

        userVote[msg.sender] = bytes32(0);
        particle.lock(msg.sender, false);
    }

    function execute() external {
        require(block.timestamp > nextEvent);

        uint256 amount = proposals[topProposal].amount;

        nextEvent = block.timestamp + 30 days;
        address payable newEvent = eventImplementation.clone(abi.encode(nextEvent));

        proposalVotes[topProposal] = 0;
        topProposal = bytes32(0);
        currentEvent = newEvent;

        SafeTransferLib.safeTransferETH(newEvent, amount);
    }

    function _updateVotes(bytes32 _proposalHash) internal {
        uint256 balance = particle.balanceOf(msg.sender);
        require(balance > 0);

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0) && proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= balance;
        } 

        if(!particle.locked(msg.sender)){
            particle.lock(msg.sender, true);
        }

        userVote[msg.sender] = _proposalHash;
        proposalVotes[_proposalHash] += balance;

        if (proposalVotes[_proposalHash] > proposalVotes[topProposal]){
            topProposal = _proposalHash;
        }
    }
}

