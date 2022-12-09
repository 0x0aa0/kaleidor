// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {IParticle} from "./interfaces/IParticle.sol";
import {IEvent, Solution} from "./interfaces/IEvent.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";

contract Event is IEvent, Clone{
    address public immutable particle;
    address public immutable kaleidor;

    uint256 public totalVotes;

    mapping(bytes32 => Solution) public solutions;
    mapping(bytes32 => uint256) public solutionVotes;

    mapping(address => bytes32) public userVote;
    mapping(address => uint256) public lastVote;

    modifier validTime() {
        if(block.timestamp > _getArgUint256(0)) revert EventEnded();
        _;
    }
    
    receive() external payable {}

    fallback() external payable {}

    constructor(address _particle){
        particle = _particle;
        kaleidor = msg.sender;
    }

    function create(Solution calldata _solution) external validTime returns(bytes32 _solutionHash){
        _solutionHash = keccak256(abi.encode(_solution, msg.sender));
        solutions[_solutionHash] = _solution;
    }

    function vote(bytes32 _solutionHash) external validTime {
        if(_solutionHash == bytes32(0)) revert InvalidSolution();

        uint256 balance = IParticle(particle).balance(msg.sender);
        if(balance == 0) revert NoTokens();

        bytes32 prevVote = userVote[msg.sender];
        if (prevVote == bytes32(0)){
            totalVotes += balance;
        } else {
            solutionVotes[prevVote] -= lastVote[msg.sender];
        }

        userVote[msg.sender] = _solutionHash;
        solutionVotes[_solutionHash] += balance;
        lastVote[msg.sender] = balance;
    }

    function unvote() external validTime {  
        bytes32 prevVote = userVote[msg.sender];

        solutionVotes[prevVote] -= lastVote[msg.sender];
        totalVotes -= lastVote[msg.sender];
        userVote[msg.sender] = bytes32(0);
    }

    function transferUnvote(address _user) external validTime {
        if(msg.sender != particle) revert NotAuthorized();
        
        bytes32 currentVote = userVote[_user];

        --solutionVotes[currentVote];
        --lastVote[_user];
        --totalVotes;
    }

    function claim(bytes32 _solutionHash) external {
        if(block.timestamp < _getArgUint256(0)) revert TimeNotElapsed();
        Solution memory solution = solutions[_solutionHash];
        if(msg.sender != solution.participant) revert NotAuthorized();

        uint256 amount = solutionVotes[_solutionHash] * (_getArgUint256(32) / totalVotes);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function endTime() external pure returns(uint256){
        return _getArgUint256(0);
    }

    function eventPayout() external pure returns(uint256){
        return _getArgUint256(32);
    }

    function eventInfo() external view returns(string memory title, string memory description){
        bytes32 proposalHash = bytes32(_getArgUint256(64));
        (title, description, ) = IKaleidor(kaleidor).proposals(proposalHash);
    }
}