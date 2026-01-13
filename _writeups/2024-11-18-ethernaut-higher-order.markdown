---
layout: post
title:  HigherOrder
date:   2024-11-18 -0700
description: Ethernaut - HigherOrder
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

## Challenge overview

The challenge provides a contract called `HigherOrder` and gives us a goal to claim the title of the commander. To do that we must make the `treasury` variable greater than `255`.

## Looking for Vulnerabilities

There really isn't much that can be done when interacting with this contract. We can query the variables (which gives us nothing) or call one of two existing functions. We are initially unable to call `claimLeadership` because it checks that `treasury` is greater than `255` (which it is not at the start).

```solidity
function claimLeadership() public {
  if (treasury > 255) commander = msg.sender;
  else revert("Only members of the Higher Order can become Commander");
}
```

This leaves us with only one option: try to exploit `registerTreasury`.

```solidity
function registerTreasury(uint8) public {
  assembly {
      sstore(treasury_slot, calldataload(4))
  }
}
```

It uses Solidity assembly to overwrite the `treasury` variable, but it also uses `calldata` the wrong way. If we check what `calldataload` does we get the following explanation:
* *reads a (u)int256 from message data*

In other words, it returns **msg.data[i:i+32]**. This means that we can hand-craft the payload to look like this:

- 4 bytes of function selector for calling `claimLeadership`
- `uint256(256)`

And just like that we become the commander.