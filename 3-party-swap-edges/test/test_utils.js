const { Console } = require("console");
const fs = require("fs");
const CryptoJS = require("crypto-js");
var SHA256 = require("crypto-js/sha256");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const file_prefix =  "./logs/swaps/three_party_swap_"
const file_extension = ".json"

/* make a new logger so that we can output to a log file */
const Logger = new Console({
  stdout: fs.createWriteStream("logs/stdout.txt"),
  stderr: fs.createWriteStream("logs/stderr.txt"),
});

/* function that logs a new swap instance */
const logNewSwap = (i, actionsTaken, preimage, hashLock) => {
  Logger.log("-------------------------")
  Logger.log(`iteration: ${i + 1} / 4096`)
  Logger.log("actions taken: " + actionsTaken)
  Logger.log("preimage: " + preimage)
  Logger.log("hashLock: " + hashLock)
}

/* function that logs an error that occurs during a protocol's execution */
const logError = (i, currentStep, actionsTaken, preimage, hashLock, e) => {
  Logger.error("-------------------------")
  Logger.error(`iteration: ${i + 1} / 4096`)
  Logger.error("actions taken: " + actionsTaken)
  Logger.error("current step: " + currentStep)
  Logger.error("preimage: " + preimage)
  Logger.error("hashLock: " + hashLock)
  Logger.error(e)
}

/* function that returns the most recent block's timestamp */
const getMostRecentBlockTimestamp = async () => {
  const blockNum = await web3.eth.getBlockNumber()
  const block = await web3.eth.getBlock(blockNum)
  return block['timestamp']
}

/* function that logs the events to individual .txt files*/

const logEvents = (i, apr_events, ban_events, che_events) => {
  let filepath = file_prefix + i + file_extension
  const message = `protocol: ${allProtocols[i]} \napricot: ${JSON.stringify(apr_events)} \nbanana: ${JSON.stringify(ban_events)} \ncherry: ${JSON.stringify(che_events)}`
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

const getAllProtocols = (...a) => {
  const actionsTaken = []
  const cartesian = getCartesian(...a)
  for (const possibility of cartesian) {
    actionsTaken.push(interleave(possibility))
  }
  return actionsTaken
}

//actionsTaken =[['1','1','111111110'],['0000000000'],['1111111000']]
/* function that interleaves apricot and banana actions */
const interleave = (possibility) => {
  const apr_actions = possibility[0]/// '1111'
  const ban_actions = possibility[1]///'1000'
  const che_actions = possibility[2]///
  const actions = []
  for (let i = 0; i < apr_actions.length; i++) {
    actions.push(apr_actions[i])
    actions.push(ban_actions[i])
    actions.push(che_actions[i])

  }
  return actions // actions is ['1','0',...]
}

/* Gets all possible permutations of n coin flips (or for us, whether a step was taken in time)
Adapted from: https://stackoverflow.com/questions/63570953/how-to-return-all-combinations-of-n-coin-flips-using-recursion */
const getFlips = (n) =>
  n <= 0
    ? ['']
    : getFlips (n - 1) .flatMap (r => [r + '1', r + '0'])

/* the four possible protocols we're interested in */
const combinations = getFlips(4);
const allProtocols = getAllProtocols(combinations, combinations, combinations)
/* stepsTakenInTime is an array of strings that look like '010100'  */
//const allProtocols = getFlips(12).map(x =>x.split(''));
// Logger.log(allProtocols)
/* allProtocols is an array of strings that looks like lik '0,0,1,1,0,1,0,1,0,1,0,0' */
//const allProtocols = getAllProtocols(combinations, combinations, stepsTakenInTime)


/* helper function that changes the index of a string, used when creating new preimages */
const setCharAt = (str,index,chr) => {
  if(index > str.length-1) return str;
  return str.substring(0,index) + chr + str.substring(index+1);
}

/* function that creates a new preimage/hashLock given the index of the loop*/
const getNewPairing = (index, preimage) => {
  const indexToChange = index % 64
  const newChar = parseInt(preimage[indexToChange]) + 1
  preimage = setCharAt(preimage, indexToChange, newChar)
  const hexified_preimage = CryptoJS.enc.Hex.parse(preimage)
  const actual_preimage = "0x" + hexified_preimage
  const hashLock = "0x" + SHA256(hexified_preimage).toString(CryptoJS.enc.Hex)
  return [preimage, actual_preimage, hashLock]
}

module.exports = {
  logNewSwap,
  logError,
  getMostRecentBlockTimestamp,
  logEvents,
  allProtocols,
  getNewPairing
}