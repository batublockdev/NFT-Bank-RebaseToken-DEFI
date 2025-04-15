//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DebtRebaseToken} from "../src/DebtRebaseToken.sol";
import {IRebaseToken} from "../src/Interface/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";

contract RebaseTokenTest is Test {
    //USERS
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    uint256 public userBalance = 100 ether;
    uint256 private constant PRECISION_FACTOR = 1e18;

    DebtRebaseToken private rebaseToken;
    Vault private vault;

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new DebtRebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.transferOwnership(address(vault));
        vm.stopPrank();
        // Set up initial balances
        vm.deal(owner, userBalance);
        vm.deal(user, userBalance);
        vm.deal(user2, userBalance);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    ////////////////////////////////////////
    //////////////  MATH TESTS /////////////
    ////////////////////////////////////////

    ////////////////////////////////////////
    //////////////  MATH TESTS /////////////
    ////////////////////////////////////////
    function test_totalamountEqualtoAmountoPey() public {}

    function test_amountPayEachInterval() public {
        uint256 amount = 1000 ether;
        uint256 term = 12;
        uint256 intervalRate = 1;
        uint256 loanAmount = amount;
        uint256 leftTerms = term;

        // Compound interest calculation with overflow protection
        uint256 data = PRECISION_FACTOR +
            ((intervalRate * PRECISION_FACTOR) / 100);
        for (uint256 i = 0; i < leftTerms - 1; i++) {
            data =
                (data *
                    (PRECISION_FACTOR +
                        ((intervalRate * PRECISION_FACTOR) / 100))) /
                PRECISION_FACTOR;
        }
        console.log("Data: ", data);
        uint256 denominador = (loanAmount *
            ((intervalRate * PRECISION_FACTOR) / 100) *
            data) / PRECISION_FACTOR;
        uint256 numerador = data - PRECISION_FACTOR;
        uint256 result = denominador / numerador;

        console.log("Total Amount: ", result);
    }

    function test_penalty() public {
        uint256 amount = 1000 ether;
        uint256 lastPaymentTime = block.timestamp;
        uint256 interval = 30 days;
        uint256 penaltyRate = 2 * 1e15; // 0.2% penalty rate

        vm.warp(block.timestamp + 200 days);
        vm.warp(block.timestamp + 5 hours);

        uint256 timeNoPayment = block.timestamp - lastPaymentTime;
        if (timeNoPayment > (interval + 3 days)) {
            console.log("Estamo en penalty: ", timeNoPayment);
            console.log("Estamo en penalty: ", timeNoPayment / 1 days);
            console.log(
                "Days without paying ",
                (timeNoPayment - (interval + 3 days)) / 1 days
            );
            console.log(
                "Intervals without paying ",
                (timeNoPayment - (interval + 3 days)) / interval
            );
            uint256 ecu = (PRECISION_FACTOR + penaltyRate);
            for (
                uint96 i = 0;
                i < ((timeNoPayment - (interval + 3 days)) / 1 days) - 1;
                i++
            ) {
                ecu =
                    (ecu * (PRECISION_FACTOR + penaltyRate)) /
                    PRECISION_FACTOR;
            }
            uint256 penaltyAmount = (amount * ecu) / PRECISION_FACTOR;
            console.log("Penalty Amount: ", penaltyAmount);
        }
    }
}
