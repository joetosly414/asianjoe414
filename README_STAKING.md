# ApeCoin Staking Contract

This repository contains an upgradeable ApeCoin staking contract with advanced Foundry fuzz tests.

## Overview

The project includes:

1. **ApeCoinStakingUpgradeable.sol** - Main upgradeable staking contract with:
   - Staking and withdrawing functionality
   - Reward claiming mechanism
   - User staking caps
   - Emergency withdraw capability
   - Owner controls for reward rates and caps
   - Pause/unpause functionality

2. **ApeCoinStakingUpgradeableV2.sol** - Upgraded version demonstrating:
   - Version tracking
   - Minimum stake amount requirements
   - Stake timestamp recording
   - Additional getter functions

3. **MockERC20.sol** - Testing token implementation

4. **Advanced Fuzz Tests** - Comprehensive test suite covering:
   - Multi-user scenarios
   - Cap enforcement
   - Reward calculations
   - Emergency withdrawals
   - Contract upgrades
   - Error cases

## Prerequisites

### For Foundry Development

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### For Hardhat Development

Install dependencies:
```bash
npm install
```

## Setup

1. Clone the repository:
```bash
git clone https://github.com/joetosly414/asianjoe414.git
cd asianjoe414
```

2. Install OpenZeppelin contracts for Foundry:
```bash
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
```

3. Create environment file:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## Testing

### Foundry Tests

Run the comprehensive fuzz test suite:
```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/ApeCoinStakingFuzz.t.sol

# Run fuzz tests with more runs
forge test --fuzz-runs 10000
```

### Hardhat Tests

```bash
npx hardhat test
```

## Deployment

### Using Foundry

1. Deploy to local network:
```bash
# Start local node
anvil

# Deploy (in another terminal)
forge script script/DeployApeCoinStaking.s.sol --rpc-url http://localhost:8545 --private-key $PRIVATE_KEY --broadcast
```

2. Deploy to testnet:
```bash
forge script script/DeployApeCoinStaking.s.sol --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
```

### Using Hardhat

```bash
npx hardhat run scripts/deploy.js --network localhost
npx hardhat run scripts/deploy.js --network sepolia
```

## Upgrading Contracts

### Using Foundry

```bash
# Set the proxy address from deployment
export PROXY_ADDRESS=0x...

# Run upgrade script
forge script script/UpgradeApeCoinStaking.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Using Hardhat

```bash
npx hardhat run scripts/upgrade.js --network localhost
```

## Contract Interaction

### Staking Tokens

```bash
# Approve tokens
cast send $STAKING_TOKEN "approve(address,uint256)" $PROXY_ADDRESS $AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Stake tokens
cast send $PROXY_ADDRESS "stake(uint256)" $AMOUNT --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Checking Rewards

```bash
# Check earned rewards
cast call $PROXY_ADDRESS "earned(address)" $USER_ADDRESS --rpc-url $RPC_URL

# Claim rewards
cast send $PROXY_ADDRESS "claimReward()" --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

### Admin Functions

```bash
# Set reward rate (owner only)
cast send $PROXY_ADDRESS "setRewardRate(uint256)" $NEW_RATE --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Set staking cap (owner only)
cast send $PROXY_ADDRESS "setStakingCap(uint256)" $NEW_CAP --rpc-url $RPC_URL --private-key $PRIVATE_KEY

# Emergency withdraw (owner only)
cast send $PROXY_ADDRESS "emergencyWithdraw(address)" $USER_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

## Security Features

- **Upgradeable**: Uses OpenZeppelin's upgradeable contract patterns
- **Reentrancy Protection**: All state-changing functions are protected
- **Pause Mechanism**: Contract can be paused in emergencies
- **Access Control**: Owner-only functions for critical operations
- **Safe Math**: All calculations use Solidity 0.8+ built-in overflow protection
- **Emergency Withdrawal**: Owner can rescue user funds if needed

## Testing Coverage

The fuzz test suite covers:

- ✅ Single and multi-user staking scenarios
- ✅ Staking cap enforcement
- ✅ Reward rate calculations and accumulation
- ✅ Withdrawal mechanisms
- ✅ Emergency withdrawal procedures
- ✅ Contract upgradeability
- ✅ Pause/unpause functionality
- ✅ Owner-only function access control
- ✅ Error handling and edge cases
- ✅ Token transfer safety

## Gas Optimization

The contracts are optimized for gas efficiency:
- Packed structs where possible
- Efficient storage patterns
- Minimal external calls
- Optimized loop structures

## Environment Variables

Create a `.env` file with:

```
PRIVATE_KEY=your_private_key_here
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your_project_id
MAINNET_RPC_URL=https://mainnet.infura.io/v3/your_project_id
ETHERSCAN_API_KEY=your_etherscan_api_key
PROXY_ADDRESS=deployed_proxy_address
```

## License

MIT License - see LICENSE file for details.