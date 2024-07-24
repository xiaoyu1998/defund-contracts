import { time } from "@nomicfoundation/hardhat-network-helpers";
import { sendTxn, getContractAddress, getToken, expandDecimals, contractAt} from "../utils/helper";

async function main() {
    const [owner, user] = await ethers.getSigners();

    const poolAddress = getContractAddress("Pool");
    const pool = await contractAt("Pool", poolAddress, owner);
 
    const usdtAddress = getToken("USDT")["address"];   
    const usdtDecimals = getToken("USDT")["decimals"];
    const usdt = await contractAt("MintableToken", usdtAddress);

    const balanceBeforeWithdraw = await usdt.balanceOf(user.address);
    const shareTokenAddress = await pool.shareToken();
    const shareToken = await contractAt("ShareToken", shareTokenAddress);
    const shares = await shareToken.balanceOf(owner.address);

    //close subscription
    const SubscriptionPeriodInSeconds = BigInt(24 * 60 * 60);
    await time.increase(SubscriptionPeriodInSeconds);
    await pool.withdraw(shares, user.address);
    const balanceAfterWithdraw = await usdt.balanceOf(user.address);

    console.log("balanceBeforeWithdraw", balanceBeforeWithdraw);
    console.log("balanceAfterWithdraw", balanceAfterWithdraw);
    console.log("position", await pool.entryPrices(owner.address));
    console.log("assets", await pool.getMarginsAndSupplies());
    console.log("positionInfo", await pool.getPositionsInfo());
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })