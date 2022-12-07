// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {Particle} from "./Particle.sol";
import {Proposal} from "./Kaleidor.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

struct Solution{
    string title;
    string description;
    address participant;
}

contract Event is Clone{
    Particle public immutable particle;
    address public immutable kaleidor;

    uint256 public totalVotes;

    mapping(bytes32 => Solution) solutions;
    mapping(address => bytes32) userVote;
    mapping(bytes32 => uint256) solutionVotes;

    modifier validTime(){
        require(block.timestamp < _getArgUint256(0));
        _;
    }
    
    receive() external payable {}

    fallback() external payable {}

    constructor(Particle _particle){
        particle = _particle;
        kaleidor = msg.sender;
    }

    function create(Solution memory _solution) external validTime {
        bytes32 _solutionHash = keccak256(abi.encode(_solution));
        solutions[_solutionHash] = _solution;
    }

    function vote(bytes32 _solutionHash) external validTime {
        uint256 balance = particle.balanceOf(msg.sender);
        require(balance > 0);

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote != bytes32(0)){
            solutionVotes[prevVote] -= balance;
        } else {
            totalVotes += balance;
        }

        if(!particle.locked(msg.sender)){
            particle.lock(msg.sender, true);
        }

        userVote[msg.sender] = _solutionHash;
        solutionVotes[_solutionHash] += balance;
    }

    function unvote() external validTime {
        uint256 balance = particle.balanceOf(msg.sender);
        bytes32 prevVote = userVote[msg.sender];

        solutionVotes[prevVote] -= balance;
        totalVotes -= balance;

        userVote[msg.sender] = bytes32(0);
        particle.lock(msg.sender, false);
    }

    function claim(bytes32 _solutionHash) external {
        require(block.timestamp > _getArgUint256(0));
        Solution memory solution = solutions[_solutionHash];
        require(msg.sender == solution.participant);

        uint256 amount = solutionVotes[_solutionHash] * (address(this).balance / totalVotes);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }
}