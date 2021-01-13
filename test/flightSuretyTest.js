
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');
const truffleAssert = require('truffle-assertions');

contract('Flight Surety Tests', async (accounts) => {

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
            let airlines = await config.flightSuretyData.getAirlineAddresses({from: config.owner});

            // ASSERT
            assert.equal(airlines[0], config.owner, "First airline is not registered when contract is deployed")
        });
    });

    describe('FlightSuretyApp tests', function() {
        it('(airline) can register an Airline using registerAirline() if it is funded', async function ()  {

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(config.firstAirline, "First Airline", {from: config.owner});
            }
            catch(e) {

            }
            let result = await config.flightSuretyData.isAirlineRegistered.call(config.firstAirline);

            // ASSERT
            assert.equal(result, true, "Airline should be able to register another airline");
        });

        it('(airline) cannot register an Airline using registerAirline() if it is not funded', async function () {

            // ARRANGE
            let newAirline = accounts[2];

            // ACT
            try {
                await config.flightSuretyApp.registerAirline(newAirline, 'New Airline', {from: config.firstAirline});
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

            // ACT
            try {
                await config.flightSuretyApp.fundAirline({from: config.firstAirline, value: web3.utils.toWei('7', 'ether'), gasPrice: 0});
            }
            catch(e) {
                reverted = true;
            }

            // ASSERT
            assert.equal(reverted, true, "Airline should not be able to fund itself because the amount sent is less than the minimum");
        });

        it('(airline) can fund itself using fundAirline() if it is registered', async function () {

            // ACT
            try {
                await config.flightSuretyApp.fundAirline({from: config.firstAirline, value: web3.utils.toWei('10', 'ether'), gasPrice: 0});
            }
            catch(e) {
                console.log(e);
            }
            let result = await config.flightSuretyData.isAirlineFunded.call(config.firstAirline);

            // ASSERT
            assert.equal(result, true, "Airline should be able to fund itself");
        });
    });

});
