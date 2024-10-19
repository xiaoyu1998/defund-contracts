# Defund Contracts

Non-custodial protocol, Users can deposit and withdraw assets from the vault without requiring approval from the vault manager. The vault manager will implement strategies to long and short assets, aiming to generate profits through effective vault management.

# Usage
#### Download And Installation

```shell
git clone git@github.com:xiaoyu1998/defund-contracts.git --recursive
cd defund-contracts
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
npx hardhat run scripts/01deposit.ts --network localhost
```
#### Long And Short
```shell
npx hardhat run scripts/03long.ts --network localhost
npx hardhat run scripts/04short.ts --network localhost
```
#### ClosePosition And Close
```shell
npx hardhat run scripts/05closePosition.ts --network localhost
npx hardhat run scripts/06close.ts --network localhost
```