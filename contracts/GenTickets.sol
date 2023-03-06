pragma solidity 0.6.12;

import "@openzeppelin/contracts/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Receiver.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IGenFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract GenTickets is ERC1155, ERC1155Receiver {
    using SafeMath for uint;
    //using SafeERC20 for IERC20;

    struct GenTicket {
        uint256 numTickets;
        uint256 ticketSize;
        uint totalTranches;
        uint cliffTranches;
        // In days
        uint trancheLength;
        // Each non-cliff tranche gets ticketsize / (total tranches - cliff tranches)
    }
    // Ticket id mod numTicketTypes determines tier
    // Ticket id div numTicketTypes determines tranche of ticket
    // When ticket is swapped in for tokens, the next ticket is minted to the user

    address public underlyingToken;
    mapping(uint256 => GenTicket) public genTickets;
    uint8 public numTicketTypes;
    IGenFactory public factory;
    address public issuer;
    bool public active = false;
    uint256 public balanceNeeded = 0;
    // Expected TGE timestamp, start at max uint256
    uint public TGE = type(uint).max;

    bytes private constant VALIDATOR = bytes("JC");

    constructor(
        address _underlyingToken,
        uint256[] memory _numTickets,
        uint256[] memory _ticketSizes,
        uint[] memory _totalTranches,
        uint[] memory _cliffTranches,
        uint[] memory _trancheLength,
        string memory _uri,
        IGenFactory _factory,
        address _issuer
    ) public ERC1155(_uri) {
        underlyingToken = _underlyingToken;
        factory = _factory;
        issuer = _issuer;

        for (uint8 i = 0; i < 50; i++) {
            if (_numTickets.length == i) {
                numTicketTypes = i;
                break;
            }

            balanceNeeded += _numTickets[i].mul(_ticketSizes[i]);
            genTickets[i] = GenTicket(
                _numTickets[i],
                _ticketSizes[i],
                _totalTranches[i],
                _cliffTranches[i],
                _trancheLength[i]
            );
        }
    }

    // For OpenSea
    function owner() public view virtual returns (address) {
        return issuer;
    }

    function updateTGE(uint timestamp) external {
        require(msg.sender == issuer, "GenTickets: Only issuer can update TGE");
        require(getBlockTimestamp() < TGE, "GenTickets: TGE already occurred");
        require(
            getBlockTimestamp() < timestamp,
            "GenTickets: New TGE must be in the future"
        );
        // Determine whether we want to restrict this or not
        //require(!active, "Tokens are already active");

        TGE = timestamp;
    }

    function issue(address _to) external {
        require(
            msg.sender == issuer,
            "GenTickets: Only issuer can issue the tokens"
        );
        require(!active, "GenTickets: Token is already active");
        //require(IERC20(underlyingToken).balanceOf(address(this)) >= balanceNeeded, "GenTickets: Deposit more of the underlying tokens");
        IERC20(underlyingToken).transferFrom(
            msg.sender,
            address(this),
            balanceNeeded
        );

        address feeTo = factory.feeTo();
        bytes memory data;

        for (uint8 i = 0; i < 50; i++) {
            if (numTicketTypes == i) {
                break;
            }

            GenTicket memory ticketType = genTickets[i];

            uint256 feeAmount = 0;
            if (feeTo != address(0)) {
                // 1% of tickets generated is sent to feeTo address
                feeAmount = ticketType.numTickets.div(100);
                if (feeAmount == 0) {
                    feeAmount = 1;
                }
                _mint(feeTo, i, feeAmount, data);
            }

            _mint(_to, i, ticketType.numTickets - feeAmount, data);
        }

        active = true;
    }

    function redeemTicket(address _to, uint256 _id, uint256 _amount) public {
        uint tier = _id.mod(numTicketTypes);
        GenTicket memory ticketType = genTickets[tier];

        // Check that we are past the cliff period for this ticket type
        require(
            getBlockTimestamp() >
                ticketType.trancheLength.mul(ticketType.cliffTranches).add(TGE),
            "GenTickets: Ticket is still within cliff period"
        );
        // Tranche past cliff
        uint tranche = _id.div(numTicketTypes);
        require(
            getBlockTimestamp() >
                ticketType
                    .trancheLength
                    .mul(ticketType.cliffTranches)
                    .add(ticketType.trancheLength.mul(tranche))
                    .add(TGE),
            "GenTickets: Tokens for this ticket are being vested"
        );
        require(
            tranche < ticketType.totalTranches.sub(ticketType.cliffTranches),
            "GenTickets: Ticket has redeemed all tokens"
        );

        safeTransferFrom(
            address(msg.sender),
            address(this),
            _id,
            _amount,
            VALIDATOR
        );

        // Transfer underlying tokens with corresponding ticket size
        IERC20(underlyingToken).transfer(
            _to,
            _amount.mul(ticketType.ticketSize).div(
                ticketType.totalTranches.sub(ticketType.cliffTranches)
            )
        );

        bytes memory data;
        _mint(_to, _id.add(numTicketTypes), _amount, data);
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
