# Defund Contracts

Users can deposit fund to a pool, And fund manager can have strategies to long and short assets to make profit from help manage this pool.

Users can withdraw fund from a pool, Do NOT need to get approval from the fund manager.


# Usage
#### Download and installation

```shell
git clone git@github.com:xiaoyu1998/df-contracts.git --recursive
cd df-contracts
npm install
```
#### start hardhat node
```shell
npx hardhat node
```
#### install up-contracts and copy addresses from up-contracts
```
cp deployed_addresses.json  /to/path/df-contracts/deployments/localhost_deployed_addresses.json
cp token_addresses.json  /to/path//df-contracts/deployments/localhost_token_addresses.json
```
#### deploy defund and run scripts
```shell
npx hardhat run scripts/00deployDefund.ts --network localhost
npx hardhat run scripts/01invest.ts --network localhost
npx hardhat run scripts/02withdraw.ts --network localhost
```