pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    mapping(address => uint256) private authorizedContracts;

    struct Airline {
        string name;
        bool registered;
        bool funded;
        mapping(address => bool) voters;
        uint256 votes;
    }

    mapping(address => Airline) private airlines;
    address[] airlineAddresses = new address[](0);

    struct Flight {
        bool registered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        string flight;
    }
    mapping(bytes32 => Flight) private flights;
    bytes32[] flightKeys = new bytes32[](0);

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                        CONSTRUCTOR                                       */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                )
                                public
    {
        contractOwner = msg.sender;
        airlines[msg.sender] = Airline({name: 'Owner Air', registered: true, funded: true, votes: 0});
        airlineAddresses.push(msg.sender);
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airlineAddress, string airlineName);
    event AirlineFunded(address airlineAddress, string airlineName);
    event FlightRegistered(bytes32 flightKey, address airline, string flight, uint256 timestamp);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContract() {
        require(authorizedContracts[msg.sender] == 1, "Caller is not an authorized contract");
        _;
    }

    modifier requireNotAlreadyRegistered(address airlineAddress) {
        require(!airlines[airlineAddress].registered, "Airline is already registered");
        _;
    }

    modifier requireRegisteredAirline(address airlineAddress)
    {
        require(isAirlineRegistered(airlineAddress), "Airline must be a registered airline");
        _;
    }

    modifier requireFundedAirline(address airlineAddress)
    {
        require(isAirlineFunded(airlineAddress), "Airline must be a registered airline");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational() public view returns(bool)
    {
        return operational;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus(bool mode) external requireContractOwner
    {
        operational = mode;
    }

    function authorizeCaller(address contractAddress) external requireContractOwner {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeCaller(address contractAddress) external requireContractOwner {
        delete authorizedContracts[contractAddress];
    }

    function isAirlineRegistered(address airlineAddress) public view returns(bool)
    {
        return airlines[airlineAddress].registered;
    }

    function isAirlineFunded(address airlineAddress) public view returns(bool)
    {
        return airlines[airlineAddress].funded;
    }

    function getAirlineAddresses() external view returns(address[] memory) {
        return airlineAddresses;
    }

    function isFlightRegistered(address airline, string flight, uint256 timestamp) public view returns(bool)
    {
        return flights[getFlightKey(airline, flight, timestamp)].registered;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline(address airlineAddress, string airlineName) external requireIsOperational requireAuthorizedContract requireNotAlreadyRegistered(airlineAddress)
    {
        airlines[airlineAddress] = Airline({name: airlineName, registered: true, funded: false, votes: 0});
        airlineAddresses.push(airlineAddress);
        emit AirlineRegistered(airlineAddress, airlineName);
    }

    function fundAirline(address airlineAddress) external payable requireIsOperational requireAuthorizedContract requireRegisteredAirline(airlineAddress)
    {
        airlines[airlineAddress].funded = true;
        emit AirlineFunded(airlineAddress, airlines[airlineAddress].name);
    }

    function registerFlight(address airlineAddress, string flight, uint256 timestamp) external requireIsOperational requireAuthorizedContract requireFundedAirline(airlineAddress)
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        flights[flightKey] = Flight({registered: true, statusCode: STATUS_CODE_UNKNOWN, airline: airlineAddress, flight: flight, updatedTimestamp: timestamp});
        flightKeys.push(flightKey);
        emit FlightRegistered(flightKey, airlineAddress, flight, timestamp);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buy
                            (
                            )
                            external
                            payable
                            requireIsOperational
    {

    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
                                (
                                )
                                external
                                requireIsOperational
    {
    }


    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
                            (
                            )
                            external
                            requireIsOperational
    {
    }

    function getFlightKey(address airlineAddress, string memory flight, uint256 timestamp) pure internal returns(bytes32)
    {
        return keccak256(abi.encodePacked(airlineAddress, flight, timestamp));
    }

    /**
    * @dev Fallback function
    *
    */
    function() external payable {}

}
