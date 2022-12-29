// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Clone} from "clones-with-immutable-args/Clone.sol";
import {IParticle} from "./interfaces/IParticle.sol";
import {IEvent, Solution} from "./interfaces/IEvent.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";

contract Event is IEvent, Clone{

    /// @dev particle address
    address public immutable particle;

    /// @dev kaleidor address
    address public immutable kaleidor;

    /// @dev total number of votes
    uint256 public totalVotes;
    
    /// @dev mapping for solutions
    mapping(bytes32 => Solution) public solutions;

    /// @dev mapping for solution votes
    mapping(bytes32 => uint256) public solutionVotes;

    /// @dev mapping for user vote
    mapping(address => bytes32) public userVote;

    /// @dev mapping for last vote
    mapping(address => uint256) public lastVote;

    /// @dev modifier to check if the timestamp is valid
    modifier validTime() {
        if(block.timestamp > _getArgUint256(0)) revert EventEnded();
        _;
    }
    
    /// @dev receive function 
    receive() external payable {}

    /// @dev fallback function
    fallback() external payable {}


    /// @notice Creates a new Event contract
    /// @param _particle Address of the Particle contract
    constructor(address _particle){
        particle = _particle;
        kaleidor = msg.sender;
    }

    /// @notice Creates a solution to the event
    /// @param _solution Details of the proposed solution
    /// @return The keccak256 hash of the proposed solution
    function create(Solution calldata _solution) external validTime returns(bytes32 _solutionHash){
        _solutionHash = keccak256(abi.encode(_solution, msg.sender));
        solutions[_solutionHash] = _solution;
    }

    /// @notice Casts a vote for a solution
    /// @param _solutionHash The keccak256 hash of the proposed solution
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

    /// @notice Removes a user's vote from the Event
    function unvote() external validTime {  
        bytes32 prevVote = userVote[msg.sender];

        solutionVotes[prevVote] -= lastVote[msg.sender];
        totalVotes -= lastVote[msg.sender];
        userVote[msg.sender] = bytes32(0);
    }

    /// @notice Removes a user's vote from the Event by the Particle contract
    /// @param _user The address of the user
    function transferUnvote(address _user) external validTime {
        if(msg.sender != particle) revert NotAuthorized();
        
        bytes32 currentVote = userVote[_user];

        --solutionVotes[currentVote];
        --lastVote[_user];
        --totalVotes;
    }

    /// @notice Allows a user to claim their payment if their solution is chosen
    /// @param _solutionHash The keccak256 hash of the proposed solution
    function claim(bytes32 _solutionHash) external {
        if(block.timestamp < _getArgUint256(0)) revert TimeNotElapsed();
        Solution memory solution = solutions[_solutionHash];
        if(msg.sender != solution.participant) revert NotAuthorized();

        uint256 amount = solutionVotes[_solutionHash] * (_getArgUint256(32) / totalVotes);
        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    /// @notice Returns the ending time of the Event
    /// @return The ending time of the Event
    function endTime() external pure returns(uint256){
        return _getArgUint256(0);
    }

    /// @notice Returns the total payout for the Event
    /// @return The total payout for the Event
    function eventPayout() external pure returns(uint256){
        return _getArgUint256(32);
    }

    /// @notice Returns the title and description of the Event
    /// @return The title and description of the Event
    function eventInfo() external view returns(string memory title, string memory description){
        bytes32 proposalHash = bytes32(_getArgUint256(64));
        (title, description, ) = IKaleidor(kaleidor).proposals(proposalHash);
    }
}