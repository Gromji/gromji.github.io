---
layout: post
title:  "Play to Earn"
date:   2024-08-25 -0700
description: Can you recover the burnt tokens?
tags: SekaiCTF Blockchain Writeup
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">Check out ecrecover!</span></div>
</div>

We are given three files: ArcadeMachine.sol, Coin.sol, and Setup.sol. From the Setup contract we see we need at least 13.37 ether to get the flag. The constructor shows that 19 of the 20 ether is deposited by the Setup contract. Then the ArcadeMachine contract is approved to spend 19 ether and, finally, ArcadeMachine tries to burn those 19 ether by sending them to **address(0)**.

The goal is simple: recover the “burnt” 19 ether. After digging through Coin.sol we find a suspicious-looking function that *permits* someone to use someone else's ether (similar to an *approve* function).

```solidity
function permit(
  address owner,
  address spender,
  uint256 value,
  uint256 deadline,
  uint8 v,
  bytes32 r,
  bytes32 s
) external {
  require(block.timestamp <= deadline, "signature expired");
  bytes32 structHash = keccak256(
    abi.encode(
      PERMIT_TYPEHASH,
      owner,
      spender,
      value,
      nonces[owner]++,
      deadline
      )
  );
  bytes32 h = _hashTypedDataV4(structHash);
  address signer = ecrecover(h, v, r, s);
  require(signer == owner, "invalid signer");
  allowance[owner][spender] = value;
  emit Approval(owner, spender, value);
}
```

This function asks the user to provide a signature (v, r, s) for the data, recovers the signer with **ecrecover**, and checks that the signer and owner match. That seems fine, but there is a flaw: on failure **ecrecover** returns **0**. How does that help? We can pretend we have data signed by **address(0)** and get approval to use **address(0)**’s funds. After that, the rest is straightforward.

