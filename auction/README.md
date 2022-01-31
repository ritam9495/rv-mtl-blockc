# Testing Explanation

The auction protocol has significantly more variations than the two-party and multi-party swap. 

To simpify our testing, we have set up our testing such 
that Bob is always the "winning bidder" (if he bids). None of the phase possibilities below are exhaustive, but they provide a solid set of what might happen while using this auction protocol. Since the possibilities rely on previous phases, we will expect reverting in MOST cases. 

We are assuming that Alice and Carol are actively colluding against Bob.

# Protocol

Total: 3888

## 0) Bidding \[Coin\]  
0. Neither bid
1. Just Bob bids (symmetric to just Carol bidding)
2. Both Bob and Carol bid (Bob bids first, but that's inconsequential)

## 1) Sb Revealer \[Coin\] 
0. Nobody reveals
1. Alice declares 
2. Bob challenges with [Alice, Bob]
3. Bob challenges with [Alice, Bob, Carol]
4. Carol challenges with [Alice, Carol]
5. Carol challenges with [Alice, Bob, Carol]

## 2) Sc Revealer \[Coin\]

0. Nobody reveals
1. Alice declares 
2. Bob challenges with [Alice, Bob]
3. Bob challenges with [Alice, Bob, Carol]
4. Carol challenges with [Alice, Carol]
5. Carol challenges with [Alice, Bob, Carol]
## 3) Sb Revealer \[Ticket\] 

0. Nobody reveals
1. Alice declares 
2. Bob challenges with [Alice, Bob]
3. Bob challenges with [Alice, Bob, Carol]
4. Carol challenges with [Alice, Carol]
5. Carol challenges with [Alice, Bob, Carol]
## 4) Sc Revealer \[Ticket\] 

0. Nobody reveals
1. Alice declares 
2. Bob challenges with [Alice, Bob]
3. Bob challenges with [Alice, Bob, Carol]
4. Carol challenges with [Alice, Carol]
5. Carol challenges with [Alice, Bob, Carol]
