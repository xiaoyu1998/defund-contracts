# Defund Contracts

Users can deposit asset to a pool, Users can withdraw asset from this pool, Do NOT need to get approval from the fund manager, And The fund manager can have strategies to long and short assets to make profit by help manage this pool.


# Usage
#### Download And Installation

```shell
git clone git@github.com:xiaoyu1998/df-contracts.git --recursive
cd df-contracts
npm install
```
#### Start Node
```shell
npx hardhat node
```
#### Install up-contracts And Copy Addresses From up-contracts
```
cp deployed_addresses.json  /to/path/df-contracts/deployments/localhost_deployed_addresses.json
cp token_addresses.json  /to/path//df-contracts/deployments/localhost_token_addresses.json
```
#### Deploy Defund And Run Scripts
```shell
npx hardhat run scripts/00deployDefund.ts --network localhost
npx hardhat run scripts/01invest.ts --network localhost
```
#### Long and Short
```shell
npx hardhat run scripts/03long.ts --network localhost
npx hardhat run scripts/04short.ts --network localhost
```