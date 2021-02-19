
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

var Config = async function(accounts) {

    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0x6b85cc8f612d5457d49775439335f83e12b8cfde",
        "0xcbd22ff1ded1423fbc24a7af2148745878800024",
        "0xc257274276a4e539741ca11b590b9447b26a8051",
        "0x2f2899d6d35b1a48a4fbdc93a37a72f264a9fca7"
    ];

    const TIMESTAMP = Math.floor(Date.now() / 1000);

    let owner = accounts[0];
    let airline1 = accounts[1];
    let airline2 = accounts[2];
    let airline3 = accounts[3];
    let airline4 = accounts[4];
    let airline5 = accounts[5];
    let airline6 = accounts[6];

    let flightSuretyData = await FlightSuretyData.new(airline1, 'Air Canada');
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);

    // Flights
    let flight1 = {
        airline: airline2,
        flight: "2A 111",
        timestamp: TIMESTAMP
    }
    let flight2 = {
        airline: airline2,
        flight: "2A 222",
        timestamp: TIMESTAMP
    }
    let flight3 = {
        airline: airline3,
        flight: "3A 333",
        timestamp: TIMESTAMP
    }

    // Passengers
    let passenger1 = accounts[8];
    let passenger2 = accounts[9];

    return {
        owner: owner,
        airline1: airline1,
        airline2: airline2,
        airline3: airline3,
        airline4: airline4,
        airline5: airline5,
        airline6: airline6,
        flight1: flight1,
        flight2: flight2,
        flight3: flight3,
        passenger1: passenger1,
        passenger2: passenger2,
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

module.exports = {
    Config: Config
};