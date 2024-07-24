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

    const poolAddress = getContractAddress("Pool");
    const pool = await contractAt("Pool", poolAddress, owner);
 
    const usdtAddress = getToken("USDT")["address"];   
    const usdtDecimals = getToken("USDT")["decimals"];
    const investAmountUsdt = expandDecimals(10000, usdtDecimals);
    const usdt = await contractAt("MintableToken", usdtAddress);
    console.log("usdt", await usdt.balanceOf(owner.address));
    await sendTxn(usdt.approve(poolAddress, investAmountUsdt), `usdt.approve(${poolAddress})`)  

    const multicallArgs = [
        pool.interface.encodeFunctionData("sendTokens", [usdtAddress, poolAddress, investAmountUsdt]),
        pool.interface.encodeFunctionData("invest", []),
    ];

    await sendTxn(
        pool.multicall(multicallArgs),
        "pool.multicall"
    );
    const shareTokenAddress = await pool.shareToken();
    console.log("shareTokenAddress", shareTokenAddress);
    const shareToken = await contractAt("ShareToken", shareTokenAddress);
    console.log("shares", await shareToken.balanceOf(owner.address));
    console.log("entryPrice", await pool.entryPrices(owner.address));
    console.log("assets", await getAssets(pool));
    console.log("PositionDecrease", await getPositions(pool));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })