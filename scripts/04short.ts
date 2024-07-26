import { 
    BorrowParamsStructOutput, 
    SwapParamsStructOutput 
} from "../typechain-types/contracts/";
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
    const ethAddress = getToken("ETH")["address"];
    const usdt = await contractAt("MintableToken", usdtAddress); 
    const ethDecimals = getToken("ETH")["decimals"];

    //deposit
    const usdtAsset = await getAsset(assetsBeforeLong, usdtAddress);
    const depositAmount = usdtAsset.balanceAsset;
    console.log("depositAmount", depositAmount);

    //execute borrow eth
    const borrowAmmount = expandDecimals(100, ethDecimals);
    const paramsBorrow: BorrowParamsStructOutput = {
        underlyingAsset: ethAddress,
        amount: borrowAmmount,
    };

    //execute sell eth
    const paramsSwap: SwapParamsStructOutput = {
        underlyingAssetIn: ethAddress,
        underlyingAssetOut: usdtAddress,
        amount: BigInt(borrowAmmount),
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