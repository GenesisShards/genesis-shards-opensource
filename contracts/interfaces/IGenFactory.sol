pragma solidity >=0.5.0;

interface IGenFactory {
    event TicketCreated(address indexed caller, address indexed genTicket);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getGenTicket(address) external view returns (uint);

    function genTickets(uint) external view returns (address);

    function genTicketsLength() external view returns (uint);

    function createGenTicket(
        address _underlyingToken,
        uint256[] memory _numTickets,
        uint256[] memory _ticketSizes,
        uint[] memory _totalTranches,
        uint[] memory _cliffTranches,
        uint[] memory _trancheLength,
        string memory _uri
    ) external returns (address);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}
