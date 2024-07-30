import { 
    ClosePositionParamsStructOutput 
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
    const assetsBeforeClosePosition= await getAssets(vault);

    const usdtAddress = getToken("USDT")["address"];  
    const uniAddress = getToken("UNI")["address"];

    //execute close position
    const paramsClosePosition: ClosePositionParamsStructOutput = {
        underlyingAsset: uniAddress,
        underlyingAssetUsd: usdtAddress,
    };

    const multicallArgs = [
        vault.interface.encodeFunctionData("executeClosePosition", [paramsClosePosition]),
    ];

    await sendTxn(
        vault.multicall(multicallArgs),
        "vault.multicall"
    );

    console.log("assetsBeforeClosePosition", assetsBeforeClosePosition);
    console.log("assets", await getAssets(vault));
    console.log("healthFactor", await getHealthFactor(vault));
    
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })