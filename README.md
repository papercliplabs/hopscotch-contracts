# hopscotch-contracts

Contracts for hopscotch to support payment requests that can be paid in any token

## Installation

Install the [foundry development kit](https://github.com/foundry-rs/foundry)

```
curl -L https://foundry.paradigm.xyz | bash
```

## Running unit tests

1. Run a local ethereum node by forking mainnet using [anvil](https://github.com/foundry-rs/foundry/tree/master/anvil)
    ```
    anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<alchemy_api_key>
    ```
2. Compile and run the unit tests using [forge](https://github.com/foundry-rs/foundry/tree/master/forge)
    ```
    forge test --fork-url http://localhost:8545
    ```
