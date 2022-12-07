// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SVGUtil} from "./utils/SVGUtil.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {IKaleidor, Kaleidor} from "./Kaleidor.sol";
import {IParticle} from "./interfaces/IParticle.sol";

contract Particle is IParticle, ERC721, SVGUtil, LinearVRGDA {

    address public immutable kaleidor;
    address public immutable feeReceiver;
    uint256 public immutable startTime;
    
    uint256 public totalSold;

    mapping(uint256 => address) public discoverer;
    mapping(uint256 => string) public signals;
    mapping(address => bool) public locked;

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

    function mint(string calldata _signal) external payable {
        if(block.timestamp < startTime) revert NotStarted(); 

        uint256 id = uint256(keccak256(abi.encodePacked(_signal)));
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

    function lock(address _user, bool _state) external {
        if (
            msg.sender != kaleidor && 
            msg.sender != IKaleidor(kaleidor).currentEvent()
        ) revert NotAuthorized();

        locked[_user] = _state;
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        if(locked[from]) revert Locked();
        super.transferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        if(locked[from]) revert Locked();
        super.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public override {
        if(locked[from]) revert Locked();
        super.safeTransferFrom(from, to, id, data);
    }
}
