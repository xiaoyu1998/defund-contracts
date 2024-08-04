import { 
    sendTxn, 
    getContractAddress, 
    getToken, 
    expandDecimals, 
    contractAt,
    getAssets,
    getPositions
} from "../utils/helper";

async function main() {
    const [owner, user] = await ethers.getSigners();

    const vaultAddress = getContractAddress("Vault");
    const vault = await contractAt("Vault", vaultAddress, owner);
 
    const usdtAddress = getToken("USDT")["address"];   
    const usdtDecimals = getToken("USDT")["decimals"];
    const depositAmountUsdt = expandDecimals(100000, usdtDecimals);
    const usdt = await contractAt("MintableToken", usdtAddress);
    console.log("usdt", await usdt.balanceOf(owner.address));
    await sendTxn(
        usdt.approve(vaultAddress, depositAmountUsdt), 
        `usdt.approve(${vaultAddress})`
    )  

    const multicallArgs = [
        vault.interface.encodeFunctionData("sendTokens", [usdtAddress, vaultAddress, depositAmountUsdt]),
        vault.interface.encodeFunctionData("deposit", []),
    ];

    await sendTxn(
        vault.multicall(multicallArgs),
        "vault.multicall"
    );
    const shareTokenAddress = await vault.shareToken();
    console.log("shareTokenAddress", shareTokenAddress);
    const shareToken = await contractAt("ShareToken", shareTokenAddress);
    console.log("shares", await shareToken.balanceOf(owner.address));
    console.log("entryPrice", await vault.entryPrices(owner.address));
    console.log("totalVaultFee", await vault.totalVaultFee());
    console.log("assets", await getAssets(vault));
    //console.log("Positions", await getPositions(vault));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })