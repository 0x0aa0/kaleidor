// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

struct Solution{
    string title;
    string description;
    address participant;
}

interface IEvent {

    error EventEnded();
    error NoTokens();
    error TimeNotElapsed();
    error NotAuthorized();
    error InvalidSolution();

    function particle() external returns(address);

    function kaleidor() external returns(address);

    function solutions(bytes32 _solutionHash) external returns(string memory, string memory, address);

    function userVote(address _user) external returns(bytes32);

    function solutionVotes(bytes32 _solutionHash) external returns(uint256);

    function totalVotes() external returns(uint256);

    function create(Solution calldata _solution) external returns(bytes32);

    function vote(bytes32 _solutionHash) external;

    function unvote() external;

    function transferUnvote(address _user) external;

    function claim(bytes32 _solutionHash) external;

    function endTime() external view returns(uint256);

}