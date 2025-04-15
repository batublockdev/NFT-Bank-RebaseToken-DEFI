// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address to
    ) ERC20(name, symbol) {
        _mint(to, initialSupply);
    }

    // Helper to mint more tokens in tests
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
