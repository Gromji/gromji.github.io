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

We are given a contract that does three things to the array: push, pop, or assign. This contract is also `Ownable`, which means that, in addition to its own variables, it has an `owner` variable to identify the owner (i.e., probably the creator) of the contract.

## Looking for Vulnerabilities

There is a pretty obvious underflow in the `retract` function. Because the length of the array is treated as an unsigned integer, decrementing it by one makes it huge (2<sup>256</sup>). This lets us give `revise` a huge index and wrap around memory to overwrite the variable at slot 0 (which contains both the boolean `contact` and the address of `owner` in the same slot). All that is left is to calculate the start of the array (the keccak hash of the address of the slot where the array length is stored), subtract from 2<sup>256</sup>, and pass it to `revise` with the value we want—most likely our address.