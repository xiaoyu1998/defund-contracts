import { BorrowParamsStructOutput, SwapParamsStructOutput } from "../typechain-types/contracts/";
import { 
    sendTxn, 
    getContractAddress, 
    getToken, 
    expandDecimals, 
    contractAt,
    getAsset,
    getAssets,
    getPositions
} from "../utils/helper";

async function main() {
    const [owner, user] = await ethers.getSigners();

    const poolAddress = getContractAddress("Pool");
    const pool = await contractAt("Pool", poolAddress, owner);
    const assetsBeforeLong = await getAssets(pool);

    const usdtAddress = getToken("USDT")["address"];  
    const uniAddress = getToken("UNI")["address"];
    const usdt = await contractAt("MintableToken", usdtAddress); 
    const usdtDecimals = getToken("USDT")["decimals"];

    //deposit
    const usdtAsset = await getAsset(assetsBeforeLong, usdtAddress);
    const depositAmount = usdtAsset.balanceAsset;
    console.log("depositAmount", depositAmount);

    //execute borrow
    const borrowAmmount = expandDecimals(1500000, usdtDecimals);
    const paramsBorrow: BorrowParamsStructOutput = {
        underlyingAsset: usdtAddress,
        amount: borrowAmmount,
    };

    //execute swap
    const paramsSwap: SwapParamsStructOutput = {
        underlyingAssetIn: usdtAddress,
        underlyingAssetOut: uniAddress,
        amount: depositAmount + BigInt(borrowAmmount),
        sqrtPriceLimitX96: 0
    };

    const multicallArgs = [
        pool.interface.encodeFunctionData("borrow", [paramsBorrow]),
        pool.interface.encodeFunctionData("swap", [paramsSwap]),
    ];

    await sendTxn(
        pool.multicall(multicallArgs),
        "pool.multicall"
    );

    console.log("assets", await getAssets(pool));
    //console.log("Positions", await getPositions(pool));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })