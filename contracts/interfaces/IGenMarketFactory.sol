pragma solidity >=0.5.0;

interface IGenMarketFactory {
    event MarketCreated(address indexed caller, address indexed genMarket);

    function feeTo() external view returns (address);
    function feeDivisor() external view returns (uint256);
    function feeToSetter() external view returns (address);

    function getGenMarket(address) external view returns (uint);
    function ticketToMarket(address) external view returns (address);
    function genMarkets(uint) external view returns (address);
    function genMarketsLength() external view returns (uint);

    function createGenMarket(
        address _genTicket,
        // Prices are in ETH
        uint256[] memory _prices,
        // Number of each ticket type being sold
        uint256[] memory _numTickets,
        uint256[] memory _purchaseLimits
    ) external returns (address);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
    function setFeeDivisor(uint256) external;
}