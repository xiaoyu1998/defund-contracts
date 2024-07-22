import { sendTxn, deployContract, getContractAddress, setContractAddress, getToken, expandDecimals} from "../utils/helper";

async function main() {
    const [owner] = await ethers.getSigners();

    const dataStore = getContractAddress("DataStore");
    const reader = getContractAddress("Reader");
    const router = getContractAddress("Router");
    const exchangeRouter = getContractAddress("ExchangeRouter");
    const usdt = getToken("USDT")["address"];
    const usdtDecimals = getToken("USDT")["decimals"];


    const fundStrategy = await deployContract("FundStrategy", [
      expandDecimals(300, 25), //300%
        24*60*60, //a day
        100, //5/1000
        expandDecimals(200, 25), //200%
        expandDecimals(20, 25)//20%
    ]);


    const factory = await deployContract("Factory", [
        dataStore, 
        reader,
        router,
        exchangeRouter, 
        usdt, 
        usdtDecimals
    ]);

    await sendTxn(
        factory.createPool(fundStrategy),
        `factory.createPool(${fundStrategy.target})`
    );
    setContractAddress("DefundFactory", factory.target);
    setContractAddress("Pool", await factory.getPool(owner.address, fundStrategy.target));

}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error)
    process.exit(1)
  })