pragma solidity 0.6.12;

import {GenMarket} from "./GenMarket.sol";
import "./interfaces/IGenMarketFactory.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract GenMarketFactory is IGenMarketFactory {
    using SafeMath for uint;

    // Address that receives fees
    address public override feeTo;
    uint256 public override feeDivisor;

    // Address that gets to set the feeTo address
    address public override feeToSetter;

    // List of genMarket addresses
    address[] public override genMarkets;

    mapping(address => uint) public override getGenMarket;
    // Base ticket address to market address
    mapping(address => address) public override ticketToMarket;

    event MarketCreated(address indexed caller, address indexed genMarket);

    function genMarketsLength() external view override returns (uint) {
        return genMarkets.length;
    }

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function createGenMarket(
        address _genTicket,
        // Prices are in ETH
        uint256[] memory _prices,
        // Number of each ticket type being sold
        uint256[] memory _numTickets,
        uint256[] memory _purchaseLimits
    ) external override returns (address) {
        require(
            _numTickets.length == _prices.length,
            "GenMarketFactory: ARRAY SIZE MISMATCH"
        );
        //address creator = msg.sender;
        GenMarket gm = new GenMarket(
            _genTicket,
            _prices,
            _numTickets,
            _purchaseLimits,
            this,
            msg.sender
        );
        // Populate mapping
        getGenMarket[address(gm)] = genMarkets.length;
        ticketToMarket[_genTicket] = address(gm);
        // Add to list
        genMarkets.push(address(gm));
        emit MarketCreated(msg.sender, address(gm));

        return address(gm);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "GenMarketFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "GenMarketFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }

    function setFeeDivisor(uint256 _feeDivisor) external override {
        require(msg.sender == feeToSetter, "GenMarketFactory: FORBIDDEN");
        require(
            _feeDivisor > 0,
            "GenMarketFactory: Fee divisor must not be zero"
        );
        feeDivisor = _feeDivisor;
    }
}
