# Lottery Smart Contract

Welcome to the **Lottery** project! This is a decentralized, one-time-use lottery smart contract built on Ethereum using Solidity and powered by Chainlink VRF (Verifiable Random Function) for secure randomness. Designed as a learning exercise and proof-of-concept, this project demonstrates key blockchain concepts like token integration, state management, and automated testing.

## Overview

The Lottery contract allows users to purchase tickets using LINK tokens during a predefined sale period. Once the sale ends, the contract owner can trigger a winner selection process using Chainlink VRF, ensuring a fair and tamper-proof draw. The winner can then claim the accumulated prize pool. This is a single-use lottery, meaning it runs one cycle (ticket sales, winner pick, and payout) and is not designed for multiple rounds—perfect for a focused experiment or a one-off event.

## Features

- **Token-Based Tickets**: Users buy tickets with LINK tokens (priced at 100 wei per ticket).
- **Chainlink VRF**: Utilizes Chainlink's VRF V2+ Wrapper for cryptographically secure randomness.
- **State Management**: Tracks ticket sales, lottery state (Open, Closed), and the winner.
- **Automated Testing**: Includes comprehensive Foundry tests, forking Ethereum mainnet for realistic simulation.
- **OpenZeppelin Integration**: Leverages Ownable2Step for secure ownership transfers.

## Tech Stack

- **Language**: Solidity (v0.8.25)
- **Framework**: Foundry (for development, testing, and deployment)
- **Dependencies**: OpenZeppelin Contracts, Chainlink Contracts
- **Testing**: Foundry with mainnet forking via Alchemy

## Getting Started

1. Clone the repository: `git clone https://github.com/yourusername/lottery.git`
2. Install Foundry: Follow the instructions at [foundry.paradigm.xyz](https://foundry.paradigm.xyz).
3. Set up your `.env` file with an Alchemy API key: `ALCHEMY_URL=https://eth-mainnet.g.alchemy.com/v2/your_api_key`.
4. Build and test: `forge build` and `forge test -vvv`.
