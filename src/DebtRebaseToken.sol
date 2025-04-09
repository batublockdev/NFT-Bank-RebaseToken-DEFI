//SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title DebtRebaseToken
 * @author BatuBlockDev
 * @notice The following contract is used to show the debt balances from the loans made by the users.
 * also the contract track the payments made by the users over time to manage the users scores
 * as well as apply fees to the users.
 */

contract DebtRebaseToken {
    constructor() {}
}
