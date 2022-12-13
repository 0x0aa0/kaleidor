// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Event} from "./Event.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Particle, IParticle} from "./Particle.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

contract Kaleidor is IKaleidor{
    using ClonesWithImmutableArgs for address;

    uint256 public immutable CADENCE = 5 minutes;

    address public immutable particle;
    address public immutable eventImplementation;

    bytes32 public topProposal;
    uint256 public nextEvent;
    address public currentEvent;

    mapping(bytes32 => Proposal) public proposals;
    mapping(bytes32 => uint256) public proposalVotes;
    mapping(bytes32 => bool) public executed;

    mapping(address => bytes32) public userVote;
    mapping(address => uint256) public lastVote;
    
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
        nextEvent = _startTime + CADENCE;
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

    function unvote() external {
        bytes32 prevVote = userVote[msg.sender];

        if(prevVote != bytes32(0) && !executed[prevVote]){
            proposalVotes[prevVote] -= lastVote[msg.sender];
        }

        userVote[msg.sender] = bytes32(0);
    }

    function transferUnvote(address _user) external {
        if(msg.sender != particle) revert NotAuthorized();

        bytes32 currentVote = userVote[_user];

        if(!executed[currentVote]){
            --proposalVotes[currentVote];
            --lastVote[_user];
        }
    }

    function execute() external returns (address newEvent) {
        if(block.timestamp < nextEvent) revert TimeNotElapsed();

        nextEvent = block.timestamp + CADENCE;
        uint256 amount = proposals[topProposal].amount;

        newEvent = eventImplementation.clone(
            abi.encodePacked(
                nextEvent, 
                amount, 
                uint256(topProposal)
            )
        );

        proposalVotes[topProposal] = 0;
        executed[topProposal] = true;
        topProposal = bytes32(0);
        currentEvent = newEvent;

        SafeTransferLib.safeTransferETH(newEvent, amount);
    }

    function updateTop(bytes32 _proposalHash) external {
        _updateTop(_proposalHash);
    }

    function _updateVotes(bytes32 _proposalHash) internal {
        if(_proposalHash == bytes32(0) || executed[_proposalHash]) revert InvalidProposal();

        uint256 balance = IParticle(particle).balance(msg.sender);
        if(balance == 0) revert NoTokens();

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0) && !executed[prevVote]){
            proposalVotes[prevVote] -= lastVote[msg.sender];
        } 

        userVote[msg.sender] = _proposalHash;
        lastVote[msg.sender] = balance;
        proposalVotes[_proposalHash] += balance;

        _updateTop(_proposalHash);
    }

    function _updateTop(bytes32 _proposalHash) internal {
        if (proposalVotes[_proposalHash] > proposalVotes[topProposal]){
            topProposal = _proposalHash;
        }
    }
}

