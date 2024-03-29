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

    - Goerli:

    ```
    forge script script/Hopscotch.GoerliDeploy.s.sol --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv
    ```

    - Sepolia

    ```
    forge script script/Hopscotch.SepoliaDeploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
    ```

    - Polygon

    ```
    forge script script/Hopscotch.PolygonDeploy.s.sol --rpc-url $POLYGON_RPC_URL --broadcast --verify -vvvv
    ```

    - Optimism

    ```
    forge script script/Hopscotch.OptimismDeploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv
    ```

```
forge create Hopscotch --contracts src/Hopscotch.sol --private-key <private_key> --rpc-url <rpc_url> --constructor-args <weth_addr> --etherscan-api-key <etherscan_api_key> --verify
```

Verify after

```
forge verify-contract \
    --chain-id 137 \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address)" 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270) \
    --etherscan-api-key ${POLYGONSCAN_API_KEY} \
    --compiler-version v0.8.17+commit.8df45f5f \
    0x92Ef06DBcCf841194437AfAc61BbcD5E3530fAdB \
    src/Hopscotch.sol:Hopscotch
```
