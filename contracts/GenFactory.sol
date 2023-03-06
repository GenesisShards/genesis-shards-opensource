pragma solidity 0.6.12;

import {GenTickets} from "./GenTickets.sol";
import "./interfaces/IGenFactory.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GenFactory is IGenFactory {
    using SafeMath for uint;

    // Address that receives fees
    address public override feeTo;

    // Address that gets to set the feeTo address
    address public override feeToSetter;

    // List of genToken addresses
    address[] public override genTickets;

    mapping(address => uint) public override getGenTicket;

    event TicketCreated(address indexed caller, address indexed genTicket);

    function genTicketsLength() external view override returns (uint) {
        return genTickets.length;
    }

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function createGenTicket(
        address _underlyingToken,
        uint256[] memory _numTickets,
        uint256[] memory _ticketSizes,
        uint[] memory _totalTranches,
        uint[] memory _cliffTranches,
        uint[] memory _trancheLength,
        string memory _uri
    ) external override returns (address) {
        require(_numTickets.length < 10, "GenFactory: MAX NUMBER OF TICKETS");
        require(
            _numTickets.length == _ticketSizes.length &&
                _ticketSizes.length == _totalTranches.length &&
                _totalTranches.length == _cliffTranches.length &&
                _cliffTranches.length == _trancheLength.length,
            "GenFactory: ARRAY SIZE MISMATCH"
        );
        //address issuer = msg.sender;
        GenTickets gt = new GenTickets(
            _underlyingToken,
            _numTickets,
            _ticketSizes,
            _totalTranches,
            _cliffTranches,
            _trancheLength,
            _uri,
            this,
            msg.sender
        );
        // Populate mapping
        getGenTicket[address(gt)] = genTickets.length;
        // Add to list
        genTickets.push(address(gt));
        emit TicketCreated(msg.sender, address(gt));

        return address(gt);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, "GenFactory: FORBIDDEN");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, "GenFactory: FORBIDDEN");
        feeToSetter = _feeToSetter;
    }
}
