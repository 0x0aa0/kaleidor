// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Event} from "./Event.sol";
import {Particle, IParticle} from "./Particle.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

contract Kaleidor is IKaleidor{
    using ClonesWithImmutableArgs for address;

    address public immutable particle;
    address public immutable eventImplementation;

    bytes32 public topProposal;
    uint256 public nextEvent;
    address public currentEvent;

    mapping(bytes32 => Proposal) public proposals;
    mapping(address => bytes32) public userVote;
    mapping(address => uint256) public lastVote;
    mapping(bytes32 => uint256) public proposalVotes;

    constructor(
        address _feeReceiver,
        uint256 _startTime
    ) {
        particle = address(
            new Particle(
                address(this),
                _feeReceiver,
                _startTime
            )
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
            require(msg.sender == particle);
        }

        bytes32 prevVote = userVote[_user];

        if(proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= lastVote[_user];
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
        require(_proposalHash != bytes32(0));

        uint256 balance = IParticle(particle).balance(msg.sender);
        if(balance == 0) revert NoTokens();

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0) && proposalVotes[prevVote] > 0){
            proposalVotes[prevVote] -= lastVote[msg.sender];
        } 

        userVote[msg.sender] = _proposalHash;
        proposalVotes[_proposalHash] += balance;
        lastVote[msg.sender] = balance;

        if (proposalVotes[_proposalHash] > proposalVotes[topProposal]){
            topProposal = _proposalHash;
        }
    }
}

