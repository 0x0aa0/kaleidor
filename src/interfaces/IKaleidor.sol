// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

struct Proposal{
    string title;
    string description;
    uint256 amount;
}

interface IKaleidor {

    error TimeNotElapsed();
    error NoTokens();
    error InvalidProposal();
    error NotAuthorized();

    function particle() external returns(address);

    function eventImplementation() external returns(address);

    function topProposal() external returns(bytes32);

    function nextEvent() external returns(uint256);

    function currentEvent() external returns(address);

    function proposals(bytes32 _proposalHash) external view returns(string memory, string memory, uint256);

    function userVote(address _user) external returns(bytes32);

    function proposalVotes(bytes32 _proposalHash) external returns(uint256);

    function create(Proposal memory _proposal) external returns(bytes32 _proposalHash);

    function vote(bytes32 _proposalHash) external;

    function unvote() external;

    function transferUnvote(address _user) external;

    function execute() external returns(address newEvent);
    
}