---
layout: post
title:  "Sekai Lending"
date:   2025-08-17 -0700
description: "Welcome to fun lending service!"
tags: SekaiCTF Blockchain Writeup Sui Move
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">An instance of <b>UserPosition</b> isn't bound to any specific <b>SEKAI_LENDING</b></span></div>
</div>

# Introduction
In this writeup, I break down my solution to the `Sekai Lending` challenge from **SekaiCTF 2025**—a coin‑lending service built on the Sui blockchain with a subtle but critical design flaw. This was the first Sui challenge I’ve solved!

TL;DR: Because `UserPosition` objects are not tied to any particular `SEKAI_LENDING` instance, we can liquidate a position in one pool and claim its reward from another, draining the original pool’s collateral.

# Analyzing The Challenge

The challenge uses [sui-ctf-framework](https://github.com/otter-sec/sui-ctf-framework.git) to create a testing environment and deploy modules. `framework/src/main.rs` implements a server that accepts Move bytecode (`.mv`) over a socket, deploys it in the sandbox, and calls the `solve` function with a reference to the `Challenge` object. Meanwhile, `framework-solve/src/main.rs` is a client that sends the compiled Move bytecode to that server.

## Sekai Coin and Collateral Coin

The challenge defines two coins in `sekai_coin.move` and `collateral_coin.move`. **Collateral Coin** is the asset you deposit to borrow **Sekai Coin**. On initialization, a `TreasuryCap` is created for each coin type and owned by the sender (the **challenger**).

## Challenge

The single win condition is to donate **100B** Collateral Coin and **8B** Sekai Coin to the challenge:

```rust
public fun is_solved(challenge: &Challenge) {
  assert!(balance::value(&challenge.sekai_donation) == INITIAL_SEKAI * 8 / 10 && 
  balance::value(&challenge.collateral_donation) == INITIAL_COLLATERAL, ENotSolved);
}
```

There’s also a convenient faucet: **10B** Collateral Coin is claimable by the **solver**.
 
 ```rust
public fun claim(challenge: &mut Challenge, ctx: &mut TxContext): Coin<COLLATERAL_COIN> {
  coin::from_balance(balance::split(&mut challenge.claim, INITIAL_CLAIM), ctx)
}
 ```
 
When the `create` function runs during setup, the challenge mints **10B** Collateral for claiming, and seeds the lending pool with **100B** Collateral and **10B** Sekai:

```rust
const INITIAL_COLLATERAL: u64 = 100 * 1_000_000_000;
const INITIAL_SEKAI: u64 = 100 * 1_00_000_000;
const INITIAL_CLAIM: u64 = 10 * 1_000_000_000;

public fun create(
  sekai_treasury: &mut TreasuryCap<SEKAI_COIN>,
  collateral_treasury: &mut TreasuryCap<COLLATERAL_COIN>,
  ctx: &mut TxContext
) {
  let claim = coin::into_balance(coin::mint(collateral_treasury, INITIAL_CLAIM, ctx));
  let collateral_coin = coin::mint(collateral_treasury, INITIAL_COLLATERAL, ctx);
  let sekai_coin = coin::mint(sekai_treasury, INITIAL_SEKAI, ctx);
  let sekai_lending = sekai_lending::create(collateral_coin, sekai_coin, ctx);
  ...
}
```

## Sekai Lending

`sekai_lending.move` implements the core lending logic. Users create `UserPosition` objects, deposit Collateral, and borrow Sekai against it. The vulnerability that lets us drain the challenge’s original `SEKAI_LENDING` pool lives here.

### Vulnerability

The Sekai donation part is easy if we have sufficient Collateral; we can just borrow what we need. So the real challenge is stockpiling enough **Collateral Coin** to both donate and keep borrowing. Those coins sit inside the original `SEKAI_LENDING` instance. Our goal is to extract them.

### UserPosition... but whose?

Looking closely at the objects, one thing stands out: `UserPosition` is not bound to any `SEKAI_LENDING` instance.

<div style="display: flex; align-items: stretch; justify-content: space-between;">

<pre style="flex: 1;">
<code class="language-rust">
public struct SEKAI_LENDING has key, store {
  id: UID,
  collateral_pool: Balance&lt;COLLATERAL_COIN&gt;,
  borrowed_pool: Balance&lt;SEKAI_COIN&gt;,
  total_collateral: u64,
  total_borrowed: u64,
  total_liquidations: u64,
  protocol_fees: u64,
  admin: address
}
</code>
</pre>

<pre style="flex: 1; margin-left: 10px">
<code class="language-rust">
public struct UserPosition has key, store {
  id: UID,
  collateral_amount: u64,
  borrowed_amount: u64,
  last_update: u64,
  is_liquidated: bool,
  liquidation_epoch: u64, 
  liquidation_reward: u64
}
</code>
</pre>

</div>

Intuitively, you should not be able to liquidate with one pool and claim rewards from another. But because `UserPosition` has no association to a specific `SEKAI_LENDING`, the following function can be called with any arbitrary pair of pool and position:

```rust
public fun claim_liquidation_reward(
  self: &mut SEKAI_LENDING,
  position: &mut UserPosition,
  ctx: &mut TxContext
): Coin<COLLATERAL_COIN> {
  let reward = position.liquidation_reward;
  position.liquidation_reward = 0;
  let reward_balance = balance::split(&mut self.collateral_pool, reward);
  let reward_coins = coin::from_balance(reward_balance, ctx);
  reward_coins
}
```

If we create our own `SEKAI_LENDING` instance, liquidate a position there, and then claim the reward from the original challenge pool, we effectively steal Collateral from the challenge’s pool. The function never checks that the `position` originated from `self`.

## Summary

1. Spin up our own `SEKAI_LENDING` instance.
2. Open a `UserPosition` and deposit Collateral into our pool.
3. Trigger liquidation on that position in our pool to set a non‑zero `liquidation_reward`.
4. Call `claim_liquidation_reward` on the original challenge pool, passing our `UserPosition`.
5. Reset our pool’s state back to the pre‑liquidation setup.
6. Loop steps 2–5 until we siphon off the full **110B** Collateral we need.
7. Use the extra **10B** Collateral to safely borrow the required Sekai and complete the donation.

You can find my raw solution <a href="{{ site.baseurl }}/assets/challenge_files/sekai-ctf-2025-sekai-lending-solution.txt" target="_blank">here</a>. Although somewhat messy and based on trial and error, it gets the job done. As you can see from my code, I was juggling numbers to get the desired results, but the high-level strategy is the same as described. This was a very fun challenge!