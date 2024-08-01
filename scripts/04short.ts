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
    getPositions,
    getHealthFactor
} from "../utils/helper";

async function main() {
    const [owner, user] = await ethers.getSigners();

    const vaultAddress = getContractAddress("Vault");
    const vault = await contractAt("Vault", vaultAddress, owner);
    const assetsBeforeLong = await getAssets(vault);

    const usdtAddress = getToken("USDT")["address"];  
    const uniAddress = getToken("UNI")["address"];
    const usdt = await contractAt("MintableToken", usdtAddress); 
    const uniDecimals = getToken("UNI")["decimals"];

    //execute borrow uni
    const borrowAmmount = expandDecimals(10000, uniDecimals);
    const paramsBorrow: BorrowParamsStructOutput = {
        underlyingAsset: uniAddress,
        amount: borrowAmmount,
    };

    //execute sell uni
    const paramsSwap: SwapParamsStructOutput = {
        underlyingAssetIn: uniAddress,
        underlyingAssetOut: usdtAddress,
        amount: borrowAmmount,
        sqrtPriceLimitX96: 0
    };

    const multicallArgs = [
        vault.interface.encodeFunctionData("executeBorrow", [paramsBorrow]),
        vault.interface.encodeFunctionData("executeSwapExactIn", [paramsSwap]),
    ];

    await sendTxn(
        vault.multicall(multicallArgs),
        "vault.multicall"
    );

    console.log("assets", await getAssets(vault));
    console.log("healthFactor", await getHealthFactor(vault));
    //console.log("Positions", await getPositions(vault));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })