// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Particle} from "../Particle.sol";

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

    function particle() external returns(Particle);

    function kaleidor() external returns(address);

    function solutions(bytes32 _solutionHash) external returns(string memory, string memory, address);

    function userVote(address _user) external returns(bytes32);

    function solutionVotes(bytes32 _solutionHash) external returns(uint256);

    function create(Solution calldata _solution) external;

    function vote(bytes32 _solutionHash) external;

    function unvote() external;

    function claim(bytes32 _solutionHash) external;

}