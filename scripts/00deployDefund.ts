import { sendTxn, deployContract, getContractAddress, setContractAddress, getToken, expandDecimals} from "../utils/helper";

async function main() {
    const [owner] = await ethers.getSigners();

    const dataStore = getContractAddress("DataStore");
    const reader = getContractAddress("Reader");
    const router = getContractAddress("Router");
    const exchangeRouter = getContractAddress("ExchangeRouter");
    const usdt = getToken("USDT")["address"];
    const usdtDecimals = getToken("USDT")["decimals"];
    const averageSlippage = 50 //5/1000;

    const vaultStrategy = await deployContract("VaultStrategy", [
      expandDecimals(150, 25), //3x
        24*60*60, //60 secs
        100, //1%
        expandDecimals(200, 25), //200%
        expandDecimals(20, 25)//20%
    ]);

    const factory = await deployContract("Factory", [
        dataStore, 
        reader,
        router,
        exchangeRouter, 
        usdt, 
        usdtDecimals,
        averageSlippage
    ]);

    await sendTxn(
        factory.createVault(
          "xiaoyu1998",
          "cactus",
          "CAC",
          vaultStrategy
        ),
        `factory.createVault(${vaultStrategy.target})`
    );
    setContractAddress("DevaultFactory", factory.target);
    setContractAddress("Vault", await factory.getVault(owner.address, vaultStrategy.target));
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })