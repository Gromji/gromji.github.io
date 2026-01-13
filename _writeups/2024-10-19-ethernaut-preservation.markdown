---
layout: post
title:  Preservation
date:   2024-10-19 -0700
description: Ethernaut - Preservation
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

This is a short writeup for the `Preservation` challenge on `Ethernaut`, which means I will only discuss the idea and vulnerability and won't go in detail on how to exploit the contract.

The challenge gives us two contracts: `Preservation` and `LibraryContract`. The latter is simple—it only stores a given time in the `storedTime` variable. `Preservation` references two of these contracts and can **delegate** calls to each of them. Delegate is emphasized because it has an interesting property: calling another contract's function this way executes the callee in the caller's context. The callee operates on the caller's storage. So when `setFirstTime` gets called one may think that `storedTime` is updated, but in reality `timeZone1Library` is updated.

Now that we can update the address of the first library, we can inject the address of our deployed contract there. All the deployed contract needs to do is implement `setTime` so it updates the `owner` field in the caller contract instead of the original functionality.