// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Event} from "./Event.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Particle, IParticle} from "./Particle.sol";
import {IKaleidor, Proposal} from "./interfaces/IKaleidor.sol";
import {ClonesWithImmutableArgs} from "clones-with-immutable-args/ClonesWithImmutableArgs.sol";

contract Kaleidor is IKaleidor{
    using ClonesWithImmutableArgs for address;

    /// @dev This contract clones itself at a set cadence of 5 minutes
    uint256 public immutable CADENCE = 5 minutes;

    /// @dev particle is the contract that will be cloned
    address public immutable particle;

    /// @dev eventImplementation is the contract to which the particles will be cloned
    address public immutable eventImplementation;

    /// @dev topProposal is the proposal that is currently being voted on
    bytes32 public topProposal;
     
    /// @dev nextEvent is the time of the next cloning event
    uint256 public nextEvent;

    /// @dev currentEvent is the address of the current cloning event
    address public currentEvent;

    /// @dev proposals is a mapping from proposal hash to the proposal object
    mapping(bytes32 => Proposal) public proposals;

    /// @dev proposalVotes is a mapping from proposal hash to the number of votes received
    mapping(bytes32 => uint256) public proposalVotes;

    /// @dev executed is a mapping from proposal hash to whether it has been executed
    mapping(bytes32 => bool) public executed;

    /// @dev userVote is a mapping from user address to the proposal hash they voted for
    mapping(address => bytes32) public userVote;

    /// @dev lastVote is a mapping from user address to the time of their last vote
    mapping(address => uint256) public lastVote;
    
    /// @notice Creates a new Kaleidor contract
    /// @param _feeReceiver The address to receive fees
    /// @param _startTime The UNIX timestamp at which the contract will start
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

    /// @notice Receive ETH
    /// @dev Override of the default fallback function
    receive() external payable {}

    /// @notice Create a new proposal
    /// @param _proposal The proposal
    /// @return The proposal hash
    function create(Proposal memory _proposal) external returns(bytes32 _proposalHash) {
        _proposalHash = keccak256(abi.encode(_proposal, msg.sender));
        proposals[_proposalHash] = _proposal;
        _updateVotes(_proposalHash);
    }

    /// @notice Vote for an existing proposal
    /// @param _proposalHash The proposal hash
    function vote(bytes32 _proposalHash) external {
        _updateVotes(_proposalHash);
    }

    /// @notice Unvote for an existing proposal
    function unvote() external {
        bytes32 prevVote = userVote[msg.sender];

        if(prevVote != bytes32(0) && !executed[prevVote]){
            proposalVotes[prevVote] -= lastVote[msg.sender];
        }

        userVote[msg.sender] = bytes32(0);
    }

    /// @notice Unvote for a user
    /// @param _user The user to unvote
    function transferUnvote(address _user) external {
        if(msg.sender != particle) revert NotAuthorized();

        bytes32 currentVote = userVote[_user];

        if(!executed[currentVote]){
            --proposalVotes[currentVote];
            --lastVote[_user];
        }
    }

    /// @notice Execute the top proposal
    /// @return The address of the new Event
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

    /// @notice Update the top proposal
    /// @param _proposalHash The proposal hash
    function updateTop(bytes32 _proposalHash) external {
        _updateTop(_proposalHash);
    }

    /// @dev Updates the votes for a proposal
    /// @param _proposalHash The hash of the proposal 
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

    /// @notice functionality that updates the top proposal
    /// @param _proposalHash the proposal to update
    function _updateTop(bytes32 _proposalHash) internal {
        if (proposalVotes[_proposalHash] > proposalVotes[topProposal]){
            topProposal = _proposalHash;
        }
    }
}

