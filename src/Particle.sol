// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SVGUtil} from "./utils/SVGUtil.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";
import {IKaleidor, Kaleidor} from "./Kaleidor.sol";

contract Particle is ERC721, SVGUtil, LinearVRGDA {

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
        require(block.timestamp > startTime, "NOT STARTED"); 

        uint256 id = uint256(keccak256(abi.encodePacked(_signal)));
        require(discoverer[id] == address(0), "ALREADY DISCOVERED");

        uint256 price = getVRGDAPrice(
            toDaysWadUnsafe(
                block.timestamp - startTime
            ), 
            totalSold++
        );
        require(msg.value >= price, "UNDERPAID"); 
        

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
        require(discoverer[id] != address(0), "NOT DISCOVERED");
        string memory signal =  signals[id];
        return _manifest(id, discoverer[id], signal);
    }

    function getImage(string calldata _signal) external view returns (string memory image){
        bytes32 seed = keccak256(abi.encodePacked(_signal));
        image = _image(seed);
    }

    function lock(address _user, bool _state) external {
        require(msg.sender == kaleidor || msg.sender == IKaleidor(kaleidor).currentEvent());
        locked[_user] = _state;
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(!locked[from]);
        super.transferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) public override {
        require(!locked[from]);
        super.safeTransferFrom(from, to, id);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        bytes calldata data
    ) public override {
        require(!locked[from]);
        super.safeTransferFrom(from, to, id, data);
    }
}
