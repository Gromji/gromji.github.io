---
layout: post
title:  Preservation
date:   2024-10-19 -0700
description: Ethernaut - Preservation
tags: [Ethernaut, Blockchain, High Level Writeup]
exclude: false
---

This is a high level writeup for `Preservation` challenge on `Ethernaut` which means I will only discuss the idea and vulnerability and won't go in detail on how to exploit the contract.

Challenge gives us two contracts: `Preservation` and `LibraryContract`. The latter has simple functionality, it only stores given time in `storedTime` variable. `Preservation` has references to two of these contracts and it also has functionality to **delegate** calls to each of these contracts. Reason delegate is in bold is because it has an interesting property: calling another contract's function in such way executes the callee function in different (caller contract's) context. This means that the storage that callee contract operates upon is caller contract's storage. So when `setFirstTime` gets called one may think that `storedTime` variable is being updated, but in reality, `timeZone1Library` is being updated.

Now that we can update the address of the first library, we can simply inject address of our deployed contract there. After this, all the deployed contract needs to do is implement `setTime` function which instead of its original functionality updates `owner` field in caller contract.