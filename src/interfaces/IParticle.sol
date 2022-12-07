// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

interface IParticle {

    error NotStarted(); 
    error AlreadyDiscovered();
    error Underpaid();
    error NotDiscovered();
    error NotAuthorized();
    error Locked();

    function balance(address _user) external view returns(uint256);

    function kaleidor() external returns(address);

    function feeReceiver() external returns(address);

    function startTime() external returns(uint256);

    function totalSold() external returns(uint256);

    function discoverer(uint256 _id) external returns(address);

    function signals(uint256 _id) external returns(string memory);

    function mint(string calldata _signal) external payable;

    function getImage(string calldata _signal) external view returns (string memory);

}