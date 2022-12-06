// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {SVGUtil} from "./utils/SVGUtil.sol";
import {LinearVRGDA} from "VRGDAs/LinearVRGDA.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {toDaysWadUnsafe} from "solmate/utils/SignedWadMath.sol";

contract Particle is ERC721, SVGUtil, LinearVRGDA {

    address public immutable treasury;
    uint256 public immutable startTime;

    address public creator;
    address public feeReceiver;
    uint256 public totalSold;

    mapping(uint256 => address) public discoverer;
    mapping(uint256 => string) public signals;

    constructor(
        address _treasury,
        address _feeReceiver,
        uint256 _startTime,
        int256 _targetPrice,
        int256 _priceDecayPercent,
        int256 _perTimeUnit
    ) 
        ERC721(
            "KALEIDOR PARTICLE", 
            "*"
        ) 
        LinearVRGDA(
            _targetPrice,
            _priceDecayPercent,
            _perTimeUnit
        ) 
    {
        creator = msg.sender;
        treasury = _treasury;
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
        SafeTransferLib.safeTransferETH(treasury, contribution);
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

    function updateFeeReceiver(address _feeReceiver) external {
        require(msg.sender == creator);
        feeReceiver = _feeReceiver;
    }
}
