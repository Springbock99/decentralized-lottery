# Lottery Smart Contract

Welcome to the **Lottery** project! This is a decentralized, one-time-use lottery smart contract built on Ethereum using Solidity, powered by Chainlink VRF for secure randomness, and tested with Foundry. Created as a learning exercise by [Kent Daneel](https://github.com/Springbock99), this repository showcases blockchain development fundamentals and is open for contributions!

---

## Overview

The Lottery contract is designed for a single-use cycle: users purchase tickets with LINK tokens during a predefined sale period, the owner selects a winner using Chainlink VRF after the sale ends, and the winner claims the prize. Once the prize is distributed, the lottery concludes, making it ideal for a one-off event or a focused experiment in decentralized applications (dApps).

### Key Features

- **Token-Based Tickets**: Users buy tickets using LINK tokens (100 wei per ticket).
- **Chainlink VRF**: Ensures fair and tamper-proof winner selection with cryptographically secure randomness.
- **State Management**: Tracks ticket sales, lottery state (Open/Closed), and the winner.
- **Automated Testing**: Comprehensive Foundry tests, including mainnet forking via Alchemy.
- **OpenZeppelin Integration**: Leverages Ownable2Step for secure ownership transfers.

---

## Tech Stack

- **Language**: Solidity (v0.8.25)
- **Framework**: Foundry (for development, testing, and deployment)
- **Randomness**: Chainlink VRF V2+ Wrapper
- **Package Manager**: Soldeer (for dependency management)
- **Dependencies**:
  - [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
  - [Chainlink Contracts](https://github.com/smartcontractkit/chainlink)
- **Testing**: Foundry with mainnet forking
- **Version Control**: Git

---

## Getting Started

Follow these steps to set up and run the project locally.

### Prerequisites

- [Node.js](https://nodejs.org/) (v16 or later, if using the frontend)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (installed via `foundryup`)
- An Alchemy API key for Ethereum mainnet forking

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Springbock99/lottery.git
   cd lottery
   ```
