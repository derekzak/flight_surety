pragma solidity >=0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    FlightSuretyData flightSuretyData;

    address private contractOwner;          // Account used to deploy contract

    uint constant AIRLINE_REGISTRATION_COUNT_THRESHOLD = 4;
    uint constant AIRLINE_FUNDING_MIN_AMOUNT = 10 ether;
    uint constant PASSENGER_INSURANCE_MAX_AMOUNT = 1 ether;
    uint constant INSURANCE_PAYOUT_MULTIPLIER = 150;

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor(address dataContract) public
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

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
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");
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

    modifier requireAirlineIsFunded(address airlineAddress)
    {
        require(flightSuretyData.isAirlineFunded(airlineAddress), "Only funded airlines are allowed");
        _;
    }

    modifier requireRegisteredAirline(address airlineAddress)
    {
        require(flightSuretyData.isAirlineRegistered(airlineAddress), "Only registered arilines are allowed");
        _;
    }

    modifier requireFundingMinimum(uint amount)
    {
        require(amount >= AIRLINE_FUNDING_MIN_AMOUNT, "Funding amount is too low");
        _;
    }

    modifier requireInsuranceAmount(uint amount)
    {
        require(amount > 0 && amount <= PASSENGER_INSURANCE_MAX_AMOUNT, "Insurance amount is not correct");
        _;
    }

    modifier requireFlightIsRegistered(address airlineAddress, string flight, uint256 timestamp)
    {
        require(flightSuretyData.isFlightRegistered(airlineAddress, flight, timestamp), "Only registered flights are allowed");
        _;
    }

    modifier requireIsNotInsuredAndNotLanded(address passenger, address airlineAddress, string flight, uint256 timestamp)
    {
        require(!flightSuretyData.isFlightLanded(airlineAddress, flight, timestamp) && !flightSuretyData.isPassengerInsured(passenger, airlineAddress, flight, timestamp), "Flight is landed or passenger already has insurance");
        _;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airlineAddress, string airlineName, uint256 votes);
    event AirlineFunded(address airlineAddress, uint256 amount);
    event FlightRegistered(address airlineAddress, string flight, uint256 timestamp);
    event InsuranceBought(address airlineAddress, string flight, uint256 timestamp, address passenger, uint256 amount);

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns(bool)
    {
        return flightSuretyData.isOperational();
    }

    function make_payable(address x) internal pure returns(address)
    {
        return address(uint160(x));
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address airlineAddress, string airlineName) public requireIsOperational requireAirlineIsFunded(msg.sender) returns(bool success, uint256 votes)
    {
        flightSuretyData.registerAirline(airlineAddress, airlineName);
        votes = flightSuretyData.getAirlineVotes(airlineAddress);
        emit AirlineRegistered(airlineAddress, airlineName, votes);
        return (success, votes);
    }

   /**
    * @dev Fund an airline
    *
    */
    function fundAirline() payable external requireIsOperational requireFundingMinimum(msg.value)
    {
        make_payable(address(flightSuretyData)).transfer(AIRLINE_FUNDING_MIN_AMOUNT);
        if(msg.value > AIRLINE_FUNDING_MIN_AMOUNT) {
            msg.sender.transfer(msg.value - AIRLINE_FUNDING_MIN_AMOUNT);
        }
        flightSuretyData.fundRegisteredAirline(msg.sender);
        emit AirlineFunded(msg.sender, msg.value);
    }

   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string flight, uint256 timestamp) external requireIsOperational requireAirlineIsFunded(msg.sender) {
        flightSuretyData.registerFlight(msg.sender, flight, timestamp);
        emit FlightRegistered(msg.sender, flight, timestamp);
    }

    function buyInsurance(address airlineAddress, string flight, uint256 timestamp) external payable requireIsOperational requireInsuranceAmount(msg.value) requireRegisteredAirline(airlineAddress) requireFlightIsRegistered(airlineAddress, flight, timestamp) requireIsNotInsuredAndNotLanded(msg.sender, airlineAddress, flight, timestamp)
    {
        address(uint160(address(flightSuretyData))).transfer(msg.value);
        flightSuretyData.buyInsurance(airlineAddress, flight, timestamp, msg.sender, msg.value);
        emit InsuranceBought(airlineAddress, flight, timestamp, msg.sender, msg.value);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus(address airlineAddress, string flight, uint256 timestamp, uint8 statusCode) internal requireIsOperational
    {
        flightSuretyData.processFlightStatus(airlineAddress, flight, timestamp, statusCode, INSURANCE_PAYOUT_MULTIPLIER);
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

// FlightSuretyDdata contract
contract FlightSuretyData {
    // Utility functions
    function isOperational() public view returns(bool);
    function setOperatingStatus(bool mode) external;
    function isAirlineRegistered(address airlineAddress) external view returns(bool);
    function isAirlineFunded(address airlineAddress) external view returns(bool);
    function getAirlineVotes(address airlineAddress) external view returns(uint256);
    function getAirlineAddresses() external view returns(address[] memory);
    function isFlightRegistered(address airlineAddress, string flight, uint256 timestamp) external view returns(bool);
    function isFlightLanded(address airlineAddress, string flight, uint256 timestamp) external view returns(bool);
    function isPassengerInsured(address passenger, address airlineAddress, string flight, uint256 timestamp) external view returns(bool);

    // Contract functions
    function registerAirline(address airlineAddress, string airlineName) external;
    function fundRegisteredAirline(address airlineAddress) external;
    function registerFlight(address airlineAddress, string flight, uint256 timestamp) external;
    function processFlightStatus(address airlineAddress, string flight, uint256 timestamp, uint8 statusCode, uint256 multiplier) external;
    function buyInsurance(address airlineAddress, string flight, uint256 timestamp, address passenger, uint256 amount) external;
    function pay(address passenger) external;
}
