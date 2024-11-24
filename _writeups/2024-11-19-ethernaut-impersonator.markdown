---
layout: post
title:  Impersonator
date:   2024-11-19 -0700
description: Ethernaut - Impersonator
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">How malleable is ECDSA?</span></div>
</div>

## Challenge overview

Challenge consists of a contract which seemingly lets authorized user open the locker of a door. First, if we try to query the `ECLocker[]` array at different indices, we will find out that there already is one instance of `ECLocker` deployed. The goal of the challenge is to somehow let anyone **open** the door.

## Malleability

The way that the challenge authorizes an address to open the door is following:

```solidity
function _isValidSignature(uint8 v, bytes32 r, bytes32 s) internal returns (address) {
  address _address = ecrecover(msgHash, v, r, s);
  require (_address == controller, InvalidController());

  bytes32 signatureHash = keccak256(abi.encode([uint256(r), uint256(s), uint256(v)]));
  require (!usedSignatures[signatureHash], SignatureAlreadyUsed());

  usedSignatures[signatureHash] = true;

  return _address;
}
```

We can see that it tries to recover public key of the signer from `msgHash`, `v`, `r`, `s` values. We can easily find all of these through just querying for the values and looking for events in logs. That means we have one valid signature for `msgHash`. But what can we do if the contract makes sure we don't reuse signatures? If we understand how *ECDSA* works, we will find out that signature verification is **malleable**. This means that we can tweak retrieved signature to forge a new **valid** one. How *ECDSA* works is easily searchable online and if one follows trough with the math, they will find that if `(r, s)` is a valid signature so will be `(r, -s mod n)`.

## Exploitation

Now that we can satistfy  `_isValidSignature` function, we can just set `controller` to our desired value using this function:

```solidity
function changeController(uint8 v, bytes32 r, bytes32 s, address newController) external {
  _isValidSignature(v, r, s);
  controller = newController;
  emit ControllerChanged(newController, block.timestamp);
}
```

But the trick is that, we have to set it to a value which makes sure that **anyone** can open the door. Meaning that, even given a baldy formed signature triplet `(v, r, s)`, they should be able to open the door. The way we can exploit it is described [here]({{ site.baseurl }}/writeups/2024-08-25-sekai-ctf-play-to-earn)!