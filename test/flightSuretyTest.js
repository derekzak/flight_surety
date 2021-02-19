
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
// const truffleAssert = require('truffle-assertions');

contract('Flight Surety Tests', async (accounts) => {

    const TEST_ORACLES_COUNT = 20;
    const STATUS_CODE_LATE_AIRLINE = 20;
    var config;
    before('setup contract', async () => {
        config = await Test.Config(accounts);
        await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    describe('FlightSuretyData tests', function() {
        it(`(multiparty) has correct initial isOperational() value`, async function () {

            // Get operating status
            let status = await config.flightSuretyData.isOperational.call();
            assert.equal(status, true, "Incorrect initial operating status value");

        });

        it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

            // Ensure that access is denied for non-Contract Owner account
            let accessDenied = false;
            try
            {
                await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
            }
            catch(e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

        });

        it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

            // Ensure that access is allowed for Contract Owner account
            let accessDenied = false;
            try
            {
                await config.flightSuretyData.setOperatingStatus(false);
            }
            catch(e) {
                accessDenied = true;
            }
            assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

        });

        it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

            await config.flightSuretyData.setOperatingStatus(false);

            let reverted = false;
            try
            {
                await config.flightSurety.setTestingMode(true);
            }
            catch(e) {
                reverted = true;
            }
            assert.equal(reverted, true, "Access not blocked for requireIsOperational");

            // Set it back for other tests to work
            await config.flightSuretyData.setOperatingStatus(true);

        });

        it('(airline) first airline is registered when contract is deployed', async function () {
            // ACT
            let airlines = await config.flightSuretyData.getAirlineAddresses();

            // ASSERT
            assert.equal(airlines[0], config.airline1, "First airline is not registered when contract is deployed")
        });
    });

    describe('FlightSuretyApp tests', function() {
        it('(airline) can register an Airline using registerAirline() if it is funded', async function ()  {
            // ARRANGE
            let amount = web3.utils.toWei('10', 'ether');

            // ACT
            try {
                await config.flightSuretyApp.fundAirline({from: config.airline1, value: amount, gasPrice: 0});
                await config.flightSuretyApp.registerAirline(config.airline2, "Second Airline", {from: config.airline1});
            }
            catch(e) {

            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(config.airline2);

            // ASSERT
            assert.equal(result, true, "Airline should be able to register another airline");
        });

        it('(airline) cannot register an Airline using registerAirline() if it is not funded', async function () {

            // ARRANGE
            let newAirline = config.airline3;

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(newAirline, 'New Airline', {from: config.airline2});
            }
            catch(e) {

            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(newAirline);

            // ASSERT
            assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");
        });

        it('(airline) cannot fund itself using fundAirline() if the amount sent is not at least 10 ether', async function () {

            // ARRANGE
            let reverted = false;
            let amount = web3.utils.toWei('7', 'ether');

            // ACT
            try {
                let result = await config.flightSuretyApp.fundAirline({from: config.airline2, value: amount, gasPrice: 0});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "Airline should not be able to fund itself because the amount sent is less than the minimum");
        });

        it('(airline) can fund itself using fundAirline() if it is registered', async function () {

            // ARRANGE
            let amount = web3.utils.toWei('10', 'ether');

            // ACT
            try {
                await config.flightSuretyApp.fundAirline({from: config.airline2, value: amount, gasPrice: 0});
            }
            catch(e) {
                console.log(e);
            }
            let result = await config.flightSuretyData.isAirlineFunded.call(config.airline2);

            // ASSERT
            assert.equal(result, true, "Airline should be able to fund itself");
        });

        it('(airline) can register up to 4 airlines', async () => {

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(config.airline3, "Third Airline", {from: config.airline1});
            }
            catch(e) {
                console.log(e);
            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(config.airline3);

            // ASSERT
            assert.equal(result, true, "Registering the third airline should be possible");

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(config.airline4, "Fourth Airline", {from: config.airline1});
            }
            catch(e) {
                console.log(e);
            }
            result = await config.flightSuretyData.isAirlineRegistered.call(config.airline4);

            // ASSERT
            assert.equal(result, true, "Registering the fourth airline should be possible");
        });

        it('(airline) 5th airline requires multi-party concensus', async () => {

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(config.airline5, "Fifth Airline", {from: config.airline1});
            }
            catch(e) {
                console.log(e);
            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(config.airline5);

            // ASSERT
            assert.equal(result, false, "Registering the fifth airline should not be possible");
        });

        it('(airline) 5th airline is registered with multi-party concensus', async () => {

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(config.airline5, "Fifth Airline", {from: config.airline2});
            }
            catch(e) {
                console.log(e);
            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(config.airline5);

            // ASSERT
            assert.equal(result, true, "Registering the fifth airline should be possible");
        });

        it('(flight) funded airline can register new flights', async () => {

            // ARRANGE
            let result = undefined;

            // ACT
            try {
                await config.flightSuretyApp.registerFlight(config.flight1.flight, config.flight1.timestamp, {from: config.flight1.airline});
                await config.flightSuretyApp.registerFlight(config.flight2.flight, config.flight2.timestamp, {from: config.flight2.airline});
            }
            catch(e) {
                console.log(e);
            }
            result = await config.flightSuretyData.isFlightRegistered.call(config.flight1.airline, config.flight1.flight, config.flight1.timestamp);

            // ASSERT
            assert.equal(result, true, "Funded airline can register new flight");
        });

        it('(flight) non-funded airline cannot register new flight', async () => {

            // ARRANGE
            let reverted = false;

            // ACT
            try {
                await config.flightSuretyApp.registerFlight(config.flight3.flight, config.flight3.timestamp, {from: config.flight3.airline});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "Funded airline cannot register new flight");
        });

        it('(passenger) cannot buy insurance without a value amount', async () => {

            // ARRANGE
            let reverted = false;

            // ACT
            try {
                await config.flightSuretyApp.buyInsurance(config.flight2.airline, config.flight2.flight, config.flight2.timestamp, {from: config.passenger1, value: 0, gasPrice: 0});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "No value provided to buy insurance");
        });

        it('(passenger) cannot buy insurance above the insurance amount limit', async () => {

            // ARRANGE
            let reverted = false;

            // ACT
            try {
                await config.flightSuretyApp.buyInsurance(config.flight2.airline, config.flight2.flight, config.flight2.timestamp, {from: config.passenger1, value: web3.utils.toWei("1.5", "ether"), gasPrice: 0});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "Insurance amount is above maximum allowed limit");
        });

        it('(passenger) cannot buy insurance for non-registered flight', async () => {

            // ARRANGE
            let reverted = false;

            // ACT
            try {
                await config.flightSuretyApp.buyInsurance(config.flight3.airline, config.flight3.flight, config.flight3.timestamp, {from: config.passenger1, value: web3.utils.toWei("0.1", "ether"), gasPrice: 0});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "Flight is not registered");
        });

        it('(passenger) can buy insurance', async () => {

            // ARRANGE
            let result = undefined;

            // ACT
            try {
                await config.flightSuretyApp.buyInsurance(config.flight1.airline, config.flight1.flight, config.flight1.timestamp, {from: config.passenger1, value: web3.utils.toWei("0.5", "ether"), gasPrice: 0});
            }
            catch(e) {
                console.log(e);
            }
            result = await config.flightSuretyData.isPassengerInsured.call(config.passenger1, config.flight1.airline, config.flight1.flight, config.flight1.timestamp);

            // ASSERT
            assert.equal(result, true, "Passenger can buy insurance");
        });

        it('can register oracles', async () => {

            // ARRANGE
            let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

            // ACT
            for(let a=1; a<TEST_ORACLES_COUNT; a++) {
                await config.flightSuretyApp.registerOracle({ from: accounts[a+TEST_ORACLES_COUNT], value: fee });
                let result = await config.flightSuretyApp.getMyIndexes.call({from: accounts[a+TEST_ORACLES_COUNT]});
                //   console.log(`Oracle Registered: ${result[0]}, ${result[1]}, ${result[2]}`);
            }
        });

        it('can request flight status', async () => {

            // ACT
            // Submit a request for oracles to get status information for a flight
            await config.flightSuretyApp.fetchFlightStatus(config.flight1.airline, config.flight1.flight, config.flight1.timestamp);

            // Since the Index assigned to each test account is opaque by design
            // loop through all the accounts and for each account, all its Indexes (indices?)
            // and submit a response. The contract will reject a submission if it was
            // not requested so while sub-optimal, it's a good test of that feature
            for(let a=1; a<TEST_ORACLES_COUNT; a++) {
                // Get oracle information
                let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({ from: accounts[a+TEST_ORACLES_COUNT]});
                for(let idx=0;idx<3;idx++) {
                    try {
                        // Submit a response...it will only be accepted if there is an Index match
                        await config.flightSuretyApp.submitOracleResponse(oracleIndexes[idx], config.flight1.airline, config.flight1.flight, config.flight1.timestamp, STATUS_CODE_LATE_AIRLINE, { from: accounts[a+TEST_ORACLES_COUNT] });
                    }
                    catch(e) {
                        // Enable this when debugging
                        // console.log('\nError', idx, oracleIndexes[idx].toNumber(), flight, timestamp);
                    }
                }
            }
        });

        it('(insurance) passenger is credited the correct amount for their insurance', async () => {

            // ARRANGE
            let amount = await config.flightSuretyData.getOutstandingPaymentAmount(config.passenger1);

            // ASSERT
            assert.equal(amount, web3.utils.toWei("0.5", "ether") * 1.5, "Insurance amount not calculated correctly");
        });
    });

});
