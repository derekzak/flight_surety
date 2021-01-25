pragma solidity >=0.4.25;

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
    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    struct Insurance {
        address passenger;
        uint256 amount;
        bool credited;
    }
    mapping (bytes32 => Insurance[]) insuredPassengersByFlight;
    mapping (address => uint) public outstandingPayments;

    /********************************************************************************************/
    /*                                        CONSTRUCTOR                                       */
    /********************************************************************************************/

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor(address airlineAddress, string name) public
    {
        contractOwner = msg.sender;
        airlines[airlineAddress] = Airline({name: name, registered: true, funded: false, votes: 0});
        airlineAddresses.push(airlineAddress);
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airlineAddress, string airlineName);
    event AirlineFunded(address airlineAddress, string airlineName);
    event FlightRegistered(bytes32 flightKey, address airline, string flight, uint256 timestamp);
    event FlightStatusUpdated(address airlineAddress, string flight, uint256 timestamp, uint8 statusCode);
    event InsuranceBought(address airlineAddress, string flight, uint256 timestamp, address passenger, uint256 amount);
    event InsureeCredited(address passenger, uint256 amount);
    event PassengerPaid(address passenger, uint256 amount);

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
        require(this.isAirlineRegistered(airlineAddress), "Airline must be a registered airline");
        _;
    }

    modifier requireFundedAirline(address airlineAddress)
    {
        require(this.isAirlineFunded(airlineAddress), "Airline must be a registered airline");
        _;
    }

    modifier requireOutstandingPayments(address passenger)
    {
        require(outstandingPayments[passenger] > 0, "Passenger has no outstanding payments");
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

    function authorizeCaller(address contractAddress) external requireContractOwner
    {
        authorizedContracts[contractAddress] = 1;
    }

    function deauthorizeCaller(address contractAddress) external requireContractOwner
    {
        delete authorizedContracts[contractAddress];
    }

    function isAirlineRegistered(address airlineAddress) external view returns(bool)
    {
        return airlines[airlineAddress].registered;
    }

    function isAirlineFunded(address airlineAddress) external view returns(bool)
    {
        return airlines[airlineAddress].funded;
    }

    function getAirlineVotes(address airlineAddress) external view returns(uint256)
    {
        return airlines[airlineAddress].votes;
    }

    function getAirlineAddresses() external view returns(address[] memory)
    {
        return airlineAddresses;
    }

    function isFlightRegistered(address airlineAddress, string flight, uint256 timestamp) external view returns(bool)
    {
        return flights[getFlightKey(airlineAddress, flight, timestamp)].registered;
    }

    function isFlightLanded(address airlineAddress, string flight, uint256 timestamp) external view returns(bool)
    {
        return flights[getFlightKey(airlineAddress, flight, timestamp)].statusCode > STATUS_CODE_UNKNOWN;
    }

    function isPassengerInsured(address passenger, address airlineAddress, string flight, uint256 timestamp) external view returns(bool)
    {
        Insurance[] memory insuredPassengers = insuredPassengersByFlight[getFlightKey(airlineAddress, flight, timestamp)];
        for(uint i = 0; i < insuredPassengers.length; i++) {
            if (insuredPassengers[i].passenger == passenger) {
                return true;
            }
        }
        return false;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline(address airlineAddress, string airlineName) external requireIsOperational requireAuthorizedContract
    {
        airlines[airlineAddress] = Airline({name: airlineName, registered: true, funded: false, votes: 0});
        airlineAddresses.push(airlineAddress);
        emit AirlineRegistered(airlineAddress, airlineName);
    }

    function fundRegisteredAirline(address airlineAddress) external requireIsOperational requireAuthorizedContract
    {
        airlines[airlineAddress].funded = true;
        emit AirlineFunded(airlineAddress, airlines[airlineAddress].name);
    }

    function registerFlight(address airlineAddress, string flight, uint256 timestamp) external requireIsOperational requireAuthorizedContract
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        flights[flightKey] = Flight({registered: true, statusCode: STATUS_CODE_UNKNOWN, airline: airlineAddress, flight: flight, updatedTimestamp: timestamp});
        flightKeys.push(flightKey);
        emit FlightRegistered(flightKey, airlineAddress, flight, timestamp);
    }

    function processFlightStatus(address airlineAddress, string flight, uint256 timestamp, uint8 statusCode, uint256 multiplier) external requireIsOperational requireAuthorizedContract
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        if (flights[flightKey].statusCode == STATUS_CODE_UNKNOWN) {
            flights[flightKey].statusCode = statusCode;
            if(statusCode == STATUS_CODE_LATE_AIRLINE) {
                creditInsurees(airlineAddress, flight, timestamp, multiplier);
            }
        }
        emit FlightStatusUpdated(airlineAddress, flight, timestamp, statusCode);
    }

   /**
    * @dev Buy insurance for a flight
    *
    */
    function buyInsurance(address airlineAddress, string flight, uint256 timestamp, address passenger, uint256 amount) external requireIsOperational requireAuthorizedContract
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        insuredPassengersByFlight[flightKey].push(Insurance({passenger: passenger, amount: amount, credited: false}));
        emit InsuranceBought(airlineAddress, flight, timestamp, passenger, amount);
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees(address airlineAddress, string flight, uint256 timestamp, uint256 multiplier) internal requireIsOperational requireAuthorizedContract
    {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);
        for (uint i = 0; i < insuredPassengersByFlight[flightKey].length; i++) {
            Insurance memory insurance = insuredPassengersByFlight[flightKey][i];
            if (insurance.credited == false) {
                insurance.credited = true;
                uint256 amount = insurance.amount.mul(multiplier).div(100);
                outstandingPayments[insurance.passenger] = outstandingPayments[insurance.passenger].add(amount);
                emit InsureeCredited(insurance.passenger, amount);
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay(address passenger) external requireIsOperational requireAuthorizedContract
    {
        uint256 amount = outstandingPayments[passenger];
        outstandingPayments[passenger] = 0;
        address(uint160(passenger)).transfer(amount);
        emit PassengerPaid(passenger, amount);
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
