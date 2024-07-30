import { 
    CloseParamsStructOutput 
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
    const assetsBeforeClose= await getAssets(vault);

    const usdtAddress = getToken("USDT")["address"];  

    //execute close position
    const paramsClose: CloseParamsStructOutput = {
        underlyingAssetUsd: usdtAddress,
    };

    const multicallArgs = [
        vault.interface.encodeFunctionData("executeClose", [paramsClose]),
    ];

    await sendTxn(
        vault.multicall(multicallArgs),
        "vault.multicall"
    );

    console.log("assetsBeforeClosePosition", assetsBeforeClose);
    console.log("assets", await getAssets(vault));
    console.log("healthFactor", await getHealthFactor(vault));

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })