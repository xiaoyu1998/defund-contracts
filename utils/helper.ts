import fs from 'fs';
import path from 'path';
import parse from 'csv-parse';
import { GetMarginAndSupplyStructOutput, GetPositionInfoStructOutput } from "../typechain-types/contracts";

export async function sendTxn(txnPromise, label) {
    const txn = await txnPromise
    await txn.wait(1)
    console.info(`Sent! ${label} ${txn.hash}`)
    return txn
}

export async function contractAt(name, address, provider) {
    let contractFactory = await ethers.getContractFactory(name);
    if (provider) {
        contractFactory = contractFactory.connect(provider);
    }
    return await contractFactory.attach(address);
}

export async function deployContract(name, args, contractOptions = {}) {
    let contractFactory = await ethers.getContractFactory(name, contractOptions);
    let contract = await contractFactory.deploy(...args);
    await contract.waitForDeployment();
    return contract;
}

export const defaultRpcs = {
    localnet: "http://192.168.2.106:8545",
    localhost : "http://localhost:8545",
};

export const deployAddresses = {
    localnet : "deployments/localnet_deployed_addresses.json",
    localhost : "deployments/localhost_deployed_addresses.json",
};

export function getContractAddress(name){
    if (!process.env.HARDHAT_NETWORK){
        process.env.HARDHAT_NETWORK = 'localhost';
    }
    const jsonFile = path.join(__dirname, '..', deployAddresses[`${process.env.HARDHAT_NETWORK}`]);
    const json = JSON.parse(fs.readFileSync(jsonFile, 'utf8'))
    return json[`${name}#${name}`];    
}

export function setContractAddress(name, address){
    if (!process.env.HARDHAT_NETWORK){
        process.env.HARDHAT_NETWORK = 'localhost';
    }
    const jsonFile = path.join(__dirname, '..', deployAddresses[`${process.env.HARDHAT_NETWORK}`]);
    let addresses = JSON.parse(fs.readFileSync(jsonFile, 'utf8'));
    addresses[`${name}#${name}`] = address;
    fs.writeFileSync(jsonFile, JSON.stringify(addresses, null , 2), 'utf8');   
}

export const tokenAddresses = {
    localhost : "deployments/localhost_token_addresses.json",
    localnet : "deployments/localnet_token_addresses.json",   
};

export function getToken(name) {
    if (!process.env.HARDHAT_NETWORK){
        process.env.HARDHAT_NETWORK = 'localhost';
    }
    const tokenAddressFile = path.join(__dirname, '..', tokenAddresses[`${process.env.HARDHAT_NETWORK}`]);

    if (fs.existsSync(tokenAddressFile)) {
        return JSON.parse(fs.readFileSync(tokenAddressFile))[name];
    }
    return {}[name];
}

export function expandDecimals(n, decimals) {
    return BigInt(n)*(BigInt(10)**BigInt(decimals));
}

export function parseMarginAndSupply(s) {
    const m: GetMarginAndSupplyStructOutput = {
        underlyingAsset: s[0],
        account: s[1],
        balanceAsset: s[2],
        debt: s[3],
        borrowApy: s[4],
        maxWithdrawAmount: s[5],
        balanceSupply: s[6],
        supplyApy: s[7]
    };
    return m;
}

export async function getMarginsAndSupplies(pool) {
    const s = await pool.getMarginsAndSupplies();
    const accountMarginsAndSupplies = [];
    for (let i = 0; i < s.length; i++) {
         accountMarginsAndSupplies[i] = parseMarginAndSupply(s[i]);
    }
    return accountMarginsAndSupplies;    
}

export function parsePositionInfo(position) {
    const p: GetPositionInfoStructOutput = {
        account: position[0],
        underlyingAsset: position[1],
        positionType: position[2],
        equity: position[3],
        equityUsd: position[4],
        indexPrice: position[5],
        entryPrice: position[6],
        pnlUsd: position[7],
        liquidationPrice: position[8],
        presentageToLiquidationPrice: position[9],
    };
    return p;
}

export async function getPositionsInfo(pool) {
    const positions = await pool.getPositionsInfo();
    let ps = [];
    for (let i = 0; i < positions.length; i++) {
         ps[i] = parsePositionInfo(positions[i]);
    }
    return ps;
}