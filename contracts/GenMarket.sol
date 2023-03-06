pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IGenMarketFactory.sol";

contract GenMarket is ERC1155Receiver {
    using SafeMath for uint;

    address public genTicket;

    uint256[] public prices;
    uint256[] public numTickets;
    uint256[] public purchaseLimits;
    IGenMarketFactory public factory;
    address public creator;
    bool public active = false;
    mapping(uint256 => mapping(address => bool)) public whitelist;
    mapping(uint256 => mapping(address => uint256)) public purchases;
    mapping(uint256 => uint256) public ticketsPurchased;
    // Expected start time, start at max uint256
    uint public startTime = type(uint).max;

    bytes private constant VALIDATOR = bytes("JC");

    constructor(
        address _genTicket,
        uint256[] memory _prices,
        uint256[] memory _numTickets,
        uint256[] memory _purchaseLimits,
        IGenMarketFactory _factory,
        address _creator
    ) public {
        genTicket = _genTicket;
        prices = _prices;
        numTickets = _numTickets;
        purchaseLimits = _purchaseLimits;
        factory = _factory;
        creator = _creator;
    }

    function ticketTypes() external view returns (uint) {
        return numTickets.length;
    }

    function updateStartTime(uint timestamp) external {
        require(
            msg.sender == creator,
            "GenMarket: Only creator can update start time"
        );
        require(
            getBlockTimestamp() < startTime,
            "GenMarket: Start time already occurred"
        );
        require(
            getBlockTimestamp() < timestamp,
            "GenMarket: New start time must be in the future"
        );

        startTime = timestamp;
    }

    function setWhiteList(
        uint256 id,
        address[] memory addresses,
        bool whiteListOn
    ) external {
        require(
            msg.sender == creator,
            "GenMarket: Only creator can update whitelist"
        );
        require(
            addresses.length < 200,
            "GenMarket: Whitelist less than 200 at a time"
        );

        for (uint8 i = 0; i < 200; i++) {
            if (i == addresses.length) {
                break;
            }

            whitelist[id][addresses[i]] = whiteListOn;
        }
    }

    function deposit() external {
        require(
            msg.sender == creator,
            "GenMarket: Only the creator can deposit the tickets"
        );
        require(!active, "GenMarket: Market is already active");

        uint256[] memory tokenIDs = new uint256[](numTickets.length);
        for (uint8 i = 0; i < numTickets.length; i++) tokenIDs[i] = i;

        IERC1155(genTicket).safeBatchTransferFrom(
            msg.sender,
            address(this),
            tokenIDs,
            numTickets,
            VALIDATOR
        );

        active = true;
    }

    function buy(uint256 _id, uint256 _amount) external payable {
        require(active, "GenMarket: Market is not active");
        require(
            getBlockTimestamp() >= startTime,
            "GenMarket: Start time must pass"
        );
        require(whitelist[_id][msg.sender], "GenMarket: User not on whitelist");
        require(
            purchases[_id][msg.sender].add(_amount) <= purchaseLimits[_id],
            "GenMarket: User will exceed purchase limit"
        );
        require(
            ticketsPurchased[_id].add(_amount) <= numTickets[_id],
            "GenMarket: Not enough tickets remaining"
        );
        require(
            prices[_id].mul(_amount) <= msg.value,
            "GenMarket: Insufficient payment"
        );

        purchases[_id][msg.sender] = purchases[_id][msg.sender].add(_amount);
        ticketsPurchased[_id] = ticketsPurchased[_id].add(_amount);

        if (factory.feeTo() != address(0)) {
            // Send fees to fee address
            (bool sent, bytes memory data) = factory.feeTo().call{
                value: msg.value.div(factory.feeDivisor())
            }("");
            require(sent, "GenMarket: Failed to send Ether");
        }

        bytes memory data;
        IERC1155(genTicket).safeTransferFrom(
            address(this),
            msg.sender,
            _id,
            _amount,
            data
        );
    }

    function claim() external {
        require(msg.sender == creator, "GenMarket: Only the creator can claim");

        (bool sent, bytes memory data) = msg.sender.call{
            value: address(this).balance
        }("");
        require(sent, "GenMarket: Failed to send Ether");
    }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    /**
     * ERC1155 Token ERC1155Receiver
     */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (keccak256(_data) == keccak256(VALIDATOR)) {
            return 0xf23a6e61;
        }
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external override returns (bytes4) {
        if (keccak256(_data) == keccak256(VALIDATOR)) {
            return 0xbc197c81;
        }
    }
}
