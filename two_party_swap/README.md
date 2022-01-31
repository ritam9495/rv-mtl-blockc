@@ -1,37 +0,0 @@

# Overview

In our implementation, we tested the two-party swap protocol using the Truffle framework along with the Ganache testing framework and Chai. Testing every possible swap exchange between multiple parties would be time intensive because the chain would have to be set up repeated for each possible swap combination. To mitigate this issue, the testing protocol looped through 1024 different permutations of the swap for various protocols and, for each one, checked that the steps taken to make the swap are correct. This testing pattern gave confidence that the swap protocols were completed correctly within a reasonable amount of time.

We set up the logs for the test in such a way to keep track of each possible action taken in the atomic swap. There are 6 possible actions in the swap between each party; the Apricot (or Banana) token is deposited, escrowed, or redeemed by a given party. For example, in a successful swap, Alice can deposit a Banana token, escrow an Apricot token from Bob, or redeem the Banana token from Bob.

In our log output for the test, the order of the actions is logged to check if the swap was completed correctly. For each iteration of the atomic swap, the actions are recorded to show if the actions are taken in time and in the correct order (i.e. to redeem an Apricot token, the Apricot token must first be deposit).

## Installation

We give two options for installation on MacOS. If option 1 does not work on your computer, please try option 2.

### Option 1
Install Truffle:

```
$ npm install -g truffle
```

Install dependencies:

```
$ npm install
```

Install Chai:

```
$ npm install --save-dev chai
```

Install Ganache:

```
$ npm install -g ganache-cli
```

### Option 2

first, install nvm.

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
```
Then, on your terminal, run

```
nvm install 16
```

it will install node version v16.*.*.

Then run 
```
nvm --lts
```
to make sure you use the latest LTS version. Then you go back to option 1 with the exception that you skip 
```
npm install 
``` 
in the option 1.

## Running tests

In order to run tests, you must first instantiate a local chain using Ganache. Open a new terminal window
and run

```
$ ganache-cli
```

This will create a local test chain on port 8545.

Then, make sure there is a "swaps" folder in the "logs" folder. If not, add one

Next, in a separate terminal, navigate to the root directory of this project, `two_party_swap`.
Once there, run

```
$ truffle test <test file directory> ```

for example
```
truffle test test/all_protocols_512_test.js
```

This will run the test of you passed test file in the suite!
