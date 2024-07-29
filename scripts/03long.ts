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
    const usdtDecimals = getToken("USDT")["decimals"];

    //execute borrow usdt
    const borrowAmmount = expandDecimals(100000, usdtDecimals);
    const paramsBorrow: BorrowParamsStructOutput = {
        underlyingAsset: usdtAddress,
        amount: borrowAmmount,
    };

    //execute buy uni
    const paramsSwap: SwapParamsStructOutput = {
        underlyingAssetIn: usdtAddress,
        underlyingAssetOut: uniAddress,
        amount: borrowAmmount,
        sqrtPriceLimitX96: 0
    };

    const multicallArgs = [
        vault.interface.encodeFunctionData("executeBorrow", [paramsBorrow]),
        vault.interface.encodeFunctionData("executeSwap", [paramsSwap]),
    ];

    await sendTxn(
        vault.multicall(multicallArgs),
        "vault.multicall"
    );

    console.log("assets", await getAssets(vault));
    console.log("healthFactor", await getHealthFactor(vault));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })