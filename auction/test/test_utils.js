const { Console } = require("console");
const fs = require("fs");
const CryptoJS = require("crypto-js");
var SHA256 = require("crypto-js/sha256");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");
const console = require("console");

const file_prefix =  "./logs/auctions/auction_"
const file_extension = ".json"

/* make a new logger so that we can output to a log file */
const Logger = new Console({
  stdout: fs.createWriteStream("logs/stdout.txt"),
  stderr: fs.createWriteStream("logs/stderr.txt"),
});

/* function that logs a new swap instance */
const logNewAuction = (i, actionsTaken, preimage, hashLock, secretB, hashB, secretC, hashC) => {
  Logger.log("-------------------------")
  Logger.log(`iteration: ${i} / 512`)
  Logger.log("actions taken: " + actionsTaken)
  Logger.log("")
  Logger.log(preimage + " | preimage")
  Logger.log(hashLock + " | hashLock")
  Logger.log("")
  Logger.log(secretB + " | secretB")
  Logger.log(hashB + " | hashB")
  Logger.log("")
  Logger.log(secretC + " | secretC")
  Logger.log(hashC + " | hashC")
}

/* function that logs an error that occurs during a protocol's execution */
const logError = (i, currentStep, actionsTaken, preimage, hashLock, e) => {
  Logger.error("-------------------------")
  Logger.error(`iteration: ${i} / 224 (Coin) or 74 (Ticket)`)
  Logger.error("actions taken: " + actionsTaken)
  Logger.error("current step: " + currentStep)
  Logger.error("preimage: " + preimage)
  Logger.error("auctionID: " + hashLock)
  Logger.error(e)
}

/* function that returns the most recent block's timestamp */
const getMostRecentBlockTimestamp = async () => {
  const blockNum = await web3.eth.getBlockNumber()
  const block = await web3.eth.getBlock(blockNum)
  return block['timestamp']
}

/* function that logs the events to individual .txt files*/

const logEvents = (i, coin_events, ticketEvents) => {
  let filepath = file_prefix + i + file_extension
  const message = `protocol: ${allProtocols[i]} \nCoin: ${JSON.stringify(coin_events)}
  \nTicket: ${JSON.stringify(ticketEvents)}`
  fs.writeFile(filepath, message, 'utf8', function (err) {
    if (err) {
        console.log("An error occured while writing JSON Object to File.");
        return console.log(err);
    }
  })
}

/* function that takes the cartesian product of two arrays 
source: https://stackoverflow.com/questions/12303989/cartesian-product-of-multiple-arrays-in-javascript
*/
const getCartesian =
  (...a) => a.reduce((a, b) => a.flatMap(d => b.map(e => [d, e].flat())));

// the possible phases each protocol can have
const biddingOptions = [2, 1, 0]; // Step 0  (0 at end to have better logs first)
const revealerOptions = [1, 2, 3, 4, 5, 0]; // Steps 1, 2, 3, 4 (0 at end to have better logs first)

// an example allCoinProtocols[i] looks like [1, 1, 2, 4, 3]
const allProtocols = getCartesian(biddingOptions, revealerOptions, revealerOptions, revealerOptions, revealerOptions)

/* helper function that changes the index of a string, used when creating new preimages */
const setCharAt = (str,index,chr) => {
  if(index > str.length-1) return str;
  return str.substring(0,index) + chr + str.substring(index+1);
}

/* function that creates a new preimage/hashLock given the index of the loop*/
const getNewPairing = (index, preimage) => {
  const indexToChange = index % 64 + 2 // the + 2 is to not change the 0x
  const newChar = parseInt(preimage[indexToChange]) + 1
  preimage = setCharAt(preimage, indexToChange, newChar)
  const hexified_preimage = CryptoJS.enc.Hex.parse(preimage.substring(2))
  const actual_preimage = "0x" + hexified_preimage
  const hashLock = "0x" + SHA256(hexified_preimage).toString(CryptoJS.enc.Hex)
  return [actual_preimage, hashLock]
}

module.exports = {
  logNewAuction,
  logError,
  getMostRecentBlockTimestamp,
  logEvents,
  getNewPairing,
  allProtocols,
  Logger
}