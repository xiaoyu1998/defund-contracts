import { time } from "@nomicfoundation/hardhat-network-helpers";
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
    const usdt = await contractAt("MintableToken", usdtAddress);

    const balanceBeforeWithdraw = await usdt.balanceOf(user.address);
    const shareTokenAddress = await vault.shareToken();
    const shareToken = await contractAt("ShareToken", shareTokenAddress);
    const sharesAmount = await shareToken.balanceOf(owner.address);

    //close subscription
    const SubscriptionPeriodInSeconds = BigInt(24 * 60 * 60);
    await time.increase(SubscriptionPeriodInSeconds);
    await vault.withdraw(sharesAmount, user.address);
    const balanceAfterWithdraw = await usdt.balanceOf(user.address);

    console.log("balanceBeforeWithdraw", balanceBeforeWithdraw);
    console.log("balanceAfterWithdraw", balanceAfterWithdraw);
    console.log("shares", await shareToken.balanceOf(owner.address));
    console.log("assets", await getAssets(vault));
    //console.log("positions", await getPositions(vault));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })