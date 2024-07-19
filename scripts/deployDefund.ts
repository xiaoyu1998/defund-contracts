import { sendTxn, deployContract, getContractAddress, setContractAddress, getToken} from "../utils/helper";

async function main() {
    const [owner] = await ethers.getSigners();

    const dataStore = getContractAddress("DataStore");
    const reader = getContractAddress("Reader");
    const router = getContractAddress("Router");
    const exchangeRouter = getContractAddress("ExchangeRouter");
    const usdt = getToken("USDT")["address"];
    const usdtDecimals = getToken("USDT")["decimals"];

    const factory = await deployContract("Factory", [
      dataStore, 
      reader,
      router,
      exchangeRouter, 
      usdt, 
      usdtDecimals
    ]);

    await sendTxn(
        factory.createPool(150, 300),
        "factory.createPool(150, 300)"
    );
    setContractAddress("DefundFactory", factory.target);

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })