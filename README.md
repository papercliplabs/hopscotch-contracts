# hopscotch-contracts

Contracts for hopscotch to support payment requests that can be paid in any token

## Installation

Install the [foundry development kit](https://github.com/foundry-rs/foundry)

```
curl -L https://foundry.paradigm.xyz | bash
```

## Running unit tests

```
forge test
```

To generate gas reports
```
forge test --gas-report
```

### Old
1. Run a local ethereum node by forking mainnet using [anvil](https://github.com/foundry-rs/foundry/tree/master/anvil)
    ```
    anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<alchemy_api_key>
    ```
2. Compile and run the unit tests using [forge](https://github.com/foundry-rs/foundry/tree/master/forge)
    ```
    forge test --fork-url http://localhost:8545
    ```

## Deploying (for development)

1. Make a burner wallet, and get some Goerli ETH from a [faucet](https://goerlifaucet.com). We will use this wallet to deploy the contract to a test net.

2. Setup `.env` file

    ```
    GOERLI_RPC_URL=<alchemy_rpc_url>
    PRIVATE_KEY=<wallet_private_key>
    ETHERSCAN_API_KEY=<ethereum_api_key>
    ```

3. Source the `.env` file

    ```
    source .env
    ```

4. Deploy the contract

    ```
    forge script script/Hopscotch.s.sol --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv
    ```
