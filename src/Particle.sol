// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SVGUtil} from "./utils/SVGUtil.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IParticle} from "./interfaces/IParticle.sol";
import {IKaleidor} from "./interfaces/IKaleidor.sol";
import {IEvent} from "./interfaces/IEvent.sol";


contract Particle is IParticle, ERC721, SVGUtil, LinearVRGDA {

    address public immutable kaleidor;
    address public immutable feeReceiver;
    uint256 public immutable startTime;
    
    uint256 public totalSold;

    mapping(uint256 => address) public discoverer;
    mapping(uint256 => string) public signals;

    constructor(
        address _kaleidor,
        address _feeReceiver,
        uint256 _startTime
    ) 
        ERC721(
            "KALEIDOR PARTICLE", 
            "*"
        ) 
        LinearVRGDA(
            1e18,
            0.5e18,
            25e18
        ) 
    {
        kaleidor = _kaleidor;
        feeReceiver = _feeReceiver;
        startTime = _startTime;
    }

    function mint(string calldata _signal) external payable returns(uint256 id){
        if(block.timestamp < startTime) revert NotStarted(); 

        id = uint256(keccak256(abi.encodePacked(_signal)));
        if(discoverer[id] != address(0)) revert AlreadyDiscovered();

        uint256 price = getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - startTime
            ), 
            totalSold++
        );
        if(msg.value < price) revert Underpaid(); 
        

        discoverer[id] = msg.sender;
        signals[id] = _signal;
        _mint(msg.sender, id);

        uint256 refund = msg.value - price;
        uint256 fee = price / 20;
        uint256 contribution = price - fee;
        SafeTransferLib.safeTransferETH(msg.sender, refund);
        SafeTransferLib.safeTransferETH(feeReceiver, fee);
        SafeTransferLib.safeTransferETH(kaleidor, contribution);
    }

    function tokenURI(uint256 id) public view override returns(string memory){
        if(discoverer[id] == address(0)) revert NotDiscovered();
        string memory signal =  signals[id];
        return _manifest(id, discoverer[id], signal);
    }

    function getImage(string calldata _signal) external view returns (string memory image){
        bytes32 seed = keccak256(abi.encodePacked(_signal));
        image = _image(seed);
    }

    function balance(address _user) external view returns(uint256){
        return _balanceOf[_user];
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        _unvote(from);
        super.transferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        _unvote(from);
        super.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public override {
        _unvote(from);
        super.safeTransferFrom(from, to, id, data);
    }

    function _unvote(address _from) internal {
        if(IKaleidor(kaleidor).userVote(_from) != bytes32(0)){
            IKaleidor(kaleidor).transferUnvote(_from);
        }

        address currentEvent = IKaleidor(kaleidor).currentEvent();
        if(
            currentEvent != address(0) && 
            IEvent(currentEvent).userVote(_from) != bytes32(0)
        ){
            IEvent(currentEvent).transferUnvote(_from);
        }  
    }
}
