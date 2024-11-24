---
layout: post
title:  Alien Codex
date:   2024-11-05 -0700
description: Ethernaut - Alien Codex
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">What can go wrong by executing <b><i>array.length--</i></b></span></div>
</div>

## Challenge overview

We are given a contract which does three things to the array: push, pop or assign. This contract is also `Ownable`, which means on top of the variables that it declares it also has `owner` variable to identify the owner (i.e. probably the creator) of the contract.

## Looking for Vulnerabilities

There is a pretty obvious underflow in the `retract` function, which means that since the length of the array gets treated as unsigned integer, decrementing it by one will make it a huge (2<sup>256</sup>) value. This gives us the opportunity give `revise` function a huge index and wrap around memory to overwrite variable at slot 0 (which contains both boolean variable `contract` and address of `owner` in the same slot). So all that's left is to calculate the start of the array (which is keccack hash of the address of the slot where the length of the array is stored), subtract from 2<sup>256</sup> and pass it to the `revise` function with the value of our desire (most likely our address).