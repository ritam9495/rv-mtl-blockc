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
$ ganache-cli --gas-limit 10000000000
```

This will create a local test chain on port 8545.

Then, make sure there is a "swaps" folder in the "logs" folder. If not, add one

Next, in a separate terminal, navigate to the root directory of this project, `3-party-swap-edges`.
Once there, run

```
$ truffle test <test file directory> ```

for example
```
truffle test test/all_protocols_512_test.js
```

This will run the test of you passed test file in the suite!
