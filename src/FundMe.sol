// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

//as FundMe contract is using pricefeed from chainlink, interface defines functions to allow FundMe to use to interact with pricefeed
import {AggregatorV3Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
//priceconverter library is used to convert the data received from chainlink to whole numbers so that the many unneeded zeros are not shown
import {PriceConverter} from "../src/PriceConverter.sol";

//this defines a standardised error that can be used throughout the contract. this method is gas efficient than using revert
//revert has more gas costs associated with string manipulation
error FundMe__NotOwner();

contract FundMe {
    //this line allows contract to use functions in priceconverter that is for uint256
    using PriceConverter for uint256;

    //this stores address and maps to uint256 to store how much each address has funded the contract
    mapping(address => uint256) private s_addressToAmountFunded;
    //this creates an array called funders that stores addresses
    address[] private s_funders;

    //this defines i_owner that cannot be changed once contract is deployed
    address private immutable i_owner;
    //this line does the calculation for minimum usd, aka 5e18
    uint256 public constant MINIMUM_USD = 5 * 10 ** 18;

    AggregatorV3Interface private s_priceFeed;

    //this defines i_owner as whoever who sent the transaction to deploy FundMe, once FundMe has been deployed
    constructor(address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    //fund function requires funder to send at least 5usd in eth: taking the latest price of eth from price feed.
    //else it will revert and return string
    //if msg.value >= 5e18, add the value to msg.sender address mapping
    //add msg.sender address to array that stores all addresses of funders
    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "You need to spend more ETH!"
        );
        s_addressToAmountFunded[msg.sender] += msg.value;
        s_funders.push(msg.sender);
    }

    //getVersion function is just using the version function from interface, with the pricefeed address defined here
    function getVersion() public view returns (uint256) {
        return s_priceFeed.version();
    }

    //this modifier will make sure that msg.sender must be i_owner before it can run any function with this modifier
    modifier onlyOwner() {
        if (msg.sender != i_owner) revert FundMe__NotOwner();
        _;
    }

    //withdraw function allows only the i_owner (msg.sender who deployed fundme) to withdraw all funds added to contract by funders
    //this function checks through every index in funders array, then resets the amount they funded to 0
    //then, funders array is also reset to 0

    function cheaperWithdraw() public onlyOwner {
        uint256 fundersLength = s_funders.length;
        for (
            uint256 funderIndex = 0;
            funderIndex < fundersLength;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    function withdraw() public onlyOwner {
        for (
            uint256 funderIndex = 0;
            funderIndex < s_funders.length;
            funderIndex++
        ) {
            address funder = s_funders[funderIndex];
            s_addressToAmountFunded[funder] = 0;
        }

        s_funders = new address[](0);
        //in the call function, boolean = true is defined as callSuccess. payable(msg.sender) ensures msg.sender is payable
        //value refers to amount of eth to be transfered, and in this case, it is all the amount in the contract
        //"" is the data sent with the call. in this case, it is not used
        (bool callSuccess, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(callSuccess, "Call failed");
    }

    //if msg.sender calls function that does not exist, it will call fallback function
    fallback() external payable {
        fund();
    }

    //if msg.sender sends empty msg.data, it will call receive function
    receive() external payable {
        fund();
    }

    /**
     * view / pure functions (getters)
     */

    function getAddressToAmountFunded(
        address fundingAddress
    ) external view returns (uint256) {
        return s_addressToAmountFunded[fundingAddress];
    }

    function getFunder(uint256 index) external view returns (address) {
        return s_funders[index];
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }
}
