# 🏦 NFT-Backed Loan Protocol with Rebase Interest

This project is a decentralized finance (DeFi) protocol that allows borrowers to use NFTs as collateral to access loans, with interest managed through a dynamic rebase token system. Built entirely in Solidity using the Foundry development framework.

## 🌐 Overview

The protocol connects **borrowers** who want to unlock liquidity from their NFTs with **lenders** looking to earn interest. Interest is automatically accrued using a `RebaseToken`, which reflects growing debt over time via elastic supply mechanics.

## 📦 Contracts

### 🔹 Vault.sol

The core contract that:
- Manages NFT collateral deposits and custody
- Facilitates loan creation, terms, and agreements
- Tracks and enforces payment intervals and deadlines
- Interfaces with `RebaseToken` for debt tracking
- Handles repayment and loan liquidation logic

### 🔹 RebaseToken.sol

An ERC20-compatible token with a rebasing supply:
- Represents dynamic debt growth
- Automatically increases borrower balances over time
- Triggers can be called periodically to simulate compounding interest
- Designed to be precise and gas-efficient

## 🔁 Workflow

1. **Borrower** deposits NFT and requests a loan.
2. **Lender** submits an offer with loan amount, interest rate, term, and payment frequency.
3. **Borrower** accepts an offer. Vault locks NFT and issues funds.
4. Debt is represented via `RebaseToken`,

## 📁 Directory Structure
contracts/
  ├── Vault.sol         # Loan management
  ├── RebaseToken.sol   # Interest accrual logic

script/
  ├── Deploy.s.sol      # Deployment scripts

test/
  ├── Vault.t.sol
  ├── RebaseToken.t.sol


