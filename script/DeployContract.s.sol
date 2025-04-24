// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Script} from "forge-std/Script.sol";
import {DebtRebaseToken} from "../src/DebtRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/Interface/IRebaseToken.sol";

contract DeployContract is Script {
    address public sender;

    function run() external returns (DebtRebaseToken, Vault) {
        vm.startBroadcast();
        sender = msg.sender;
        DebtRebaseToken rebaseToken = new DebtRebaseToken();
        Vault vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.transferOwnership(address(vault));
        vm.stopBroadcast();
        return (rebaseToken, vault);
    }
}
