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

The challenge consists of a contract that seemingly lets an authorized user open a locker. If we query the `ECLocker[]` array at different indices, we see there is already one instance of `ECLocker` deployed. The goal is to let anyone **open** the door.

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

We can see that it tries to recover the public key of the signer from the `msgHash`, `v`, `r`, and `s` values. We can easily find all of these by querying the contract and checking the logs. That gives us one valid signature for `msgHash`. But what do we do when the contract prevents signature reuse? Knowing how *ECDSA* works helps: signature verification is **malleable**. We can tweak a retrieved signature to forge a new **valid** one. If `(r, s)` is a valid signature, so is `(r, -s mod n)`.

## Exploitation

Now that we can satisfy `_isValidSignature`, we can just set `controller` to our desired value using this function:

```solidity
function changeController(uint8 v, bytes32 r, bytes32 s, address newController) external {
  _isValidSignature(v, r, s);
  controller = newController;
  emit ControllerChanged(newController, block.timestamp);
}
```

The trick is that we have to set it to a value that lets **anyone** open the door. Even with a badly formed signature triplet `(v, r, s)`, they should be able to open it. How to exploit it is described [here]({{ site.baseurl }}/writeups/2024-08-25-sekai-ctf-2024-play-to-earn)!
