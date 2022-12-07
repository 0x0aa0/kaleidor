// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {Particle} from "./Particle.sol";
import {Proposal} from "./Kaleidor.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IEvent, Solution} from "./interfaces/IEvent.sol";

contract Event is IEvent, Clone{
    Particle public immutable particle;
    address public immutable kaleidor;

    uint256 public totalVotes;

    mapping(bytes32 => Solution) public solutions;
    mapping(address => bytes32) public userVote;
    mapping(bytes32 => uint256) public solutionVotes;

    modifier validTime(){
        if(block.timestamp > _getArgUint256(0)) revert EventEnded();
        _;
    }
    
    receive() external payable {}

    fallback() external payable {}

    constructor(Particle _particle){
        particle = _particle;
        kaleidor = msg.sender;
    }

    function create(Solution calldata _solution) external validTime {
        bytes32 _solutionHash = keccak256(abi.encode(_solution));
        solutions[_solutionHash] = _solution;
    }

    function vote(bytes32 _solutionHash) external validTime {
        uint256 balance = particle.balanceOf(msg.sender);
        if(balance == 0) revert NoTokens();

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0)){
            solutionVotes[prevVote] -= balance;
        } else {
            totalVotes += balance;
        }

        userVote[msg.sender] = _solutionHash;
        solutionVotes[_solutionHash] += balance;
    }

    function unvote(address _user) external validTime {
        if(_user != msg.sender){
            require(msg.sender == address(particle));
        }
        
        uint256 balance = particle.balanceOf(msg.sender);
        bytes32 prevVote = userVote[msg.sender];

        if(prevVote != bytes32(0)){
            solutionVotes[prevVote] -= balance;
            totalVotes -= balance;

            userVote[msg.sender] = bytes32(0);
        }
    }

    function claim(bytes32 _solutionHash) external {
        if(block.timestamp < _getArgUint256(0)) revert TimeNotElapsed();
        Solution memory solution = solutions[_solutionHash];
        if(msg.sender != solution.participant) revert NotAuthorized();

        uint256 amount = solutionVotes[_solutionHash] * (address(this).balance / totalVotes);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }
}