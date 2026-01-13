---
layout: post
title:  "Eldoria Gate"
date:   2025-03-21 -0700
description: Taking over the Kingdom of Eldoria
tags: ["HTB Cyber Apocalypse CTF 2025", Blockchain, Writeup]
exclude: false
---



<pre>
  <pre style="text-align: center; border: none; color: #C72C41">
      <em>
Malakar 1b:22-28, Tales from Eldoria - Eldoria Gates

In ages past, where Eldoria's glory shone,
Ancient gates stand, where shadows turn to dust.
Only the proven, with deeds and might,
May join Eldoria's hallowed, guiding light.
Through strict trials, and offerings made,
Eldoria's glory, is thus displayed.
      </em>
  </pre>
  <div style="display: flex; justify-content: center;">
    <pre style="border: none; color: #F7B300">
               ELDORIA GATES      
         *_   _   _   _   _   _  *
 ^       | `_' `-' `_' `-' `_' `-|       ^ 
 |       |                       |       |
 |  (*)  |     .___________      |  \^/  |
 | _<#>_ |    //           \     | _(#)_ |
o+o \ / \0    ||   =====   ||    0/ \ / (=)
 0'\ ^ /\/    ||           ||    \/\ ^ /`0
   /_^_\ |    ||    ---    ||    | /_^_\
   || || |    ||           ||    | || ||
   d|_|b_T____||___________||____T_d|_|b
    </pre>
  </div>
</pre>

# Challenge Files

We are given three solidity files: `Setup.sol`, `EldoriaGate.sol`, `EldoriaGateKernel.sol`.

## Setup.sol
As the name implies, this Solidity file sets up the contracts for the challenge. Like most blockchain CTF setups, it also checks whether the instance is solved.

## EldoriaGate.sol

The main logic is split into two files, one of them being `EldoriaGate.sol`. We see cool ASCII art and a description that speaks about the glory of **Eldoria**. But we must prove ourselves before we can become part of the kingdom. In our test, we see two guards protecting the gate that leads into the kingdom.

In the kingdom, villagers are assigned different roles. Each villager is described by a struct that has the following variables:

- {{ "uint id" | code_wrap: "language-solidity" }}: The unique identification number for each villager.
- {{ "bool authenticated" | code_wrap: "language-solidity" }}: Dictates whether or not the villager is allowed in Eldoria.
- {{ "uint8 roles" | code_wrap: "language-solidity" }}: The assignment of roles is based on a bitmask and is stored in this variable.

If a villager wants to enter Eldoria, they must know the secret that allows them to get past the guards at the gate. But only the worthy may obtain it (more on this later). The mapping of the villagers' roles is as follows:

<div >
<pre style="color: #C72C41; display: flex; align-items: center; justify-content: center;">
  0b00000001 -> SERF
  0b00000010 -> PEASANT 
  0b00000100 -> ARTISAN 
  0b00001000 -> MERCHANT 
  0b00010000 -> KNIGHT 
  0b00100000 -> BARON 
  0b01000000 -> EARL 
  0b10000000 -> DUKE</pre>
</div>

But here comes a good question: the setup will give us the flag if we are a usurper. However, there is no role in the mapping for that, so how do we become one?

The answer lies in the function called `checkUsurper`:

```solidity
function checkUsurper(address _villager) external returns (bool) {
    (uint id, bool authenticated , uint8 rolesBitMask) = kernel.villagers(_villager);
    bool isUsurper = authenticated && (rolesBitMask == 0);
    emit UsurperDetected(
        _villager,
        id,
        "Intrusion to benefit from Eldoria, without society responsibilities, without suspicions, via gate breach."
    );
    return isUsurper;
}
```
<pre style="color: #C72C41; display: flex; align-items: center; justify-content: center;">
 Villager has a usurper role if and only if {{ "roleBitMask" | code_wrap: "language_solidity" }} is set to 0
</pre>

## EldoriaGateKernel.sol

Remember how only the worthy get to become authenticated? Lucky for us, Malakar’s corruption has weakened the kingdom’s defenses, leaving vulnerabilities in the gate’s security system. Actually, yeah… you just need to know a password that’s publicly available. Not much of a password, eh?

To achieve this, we can use Python’s [Web3](http://github.com/ethereum/web3.py) library (which I urge the reader to try themselves) to retrieve the value of slot `0`. Let’s examine the memory layout and confirm that slot 0 holds the passphrase.

<div >
<pre style="color:rgb(146, 62, 225); display: flex; align-items: center; justify-content: center;">
╭---------------+-------------------------------------------------------+------+--------+-------╮
| Name          | Type                                                  | Slot | Offset | Bytes |
+===============================================================================================+
| eldoriaSecret | bytes4                                                | 0    | 0      | 4     |
|---------------+-------------------------------------------------------+------+--------+-------|
| villagers     | mapping(address => struct EldoriaGateKernel.Villager) | 1    | 0      | 32    |
|---------------+-------------------------------------------------------+------+--------+-------|
| frontend      | address                                               | 2    | 0      | 20    |
╰---------------+-------------------------------------------------------+------+--------+-------╯</pre>
</div>

<pre style="color: #C72C41; display: flex; align-items: center; justify-content: center;">
 Villager is authenticated if and only if they know the passphrase (2)
</pre>

# Becoming the Power

Okay, now we know the passphrase to become authenticated, but how do we set the role bitmask to `0` so that we become a *usurper*?

The function responsible for determining the role of the villager is called `evaluateIdentity`.

```solidity
function evaluateIdentity(address _unknown, uint8 _contribution) external onlyFrontend returns (uint id, uint8 roles) {
    assembly {
        mstore(0x00, _unknown)
        mstore(0x20, villagers.slot)
        let villagerSlot := keccak256(0x00, 0x40)

        mstore(0x00, _unknown)
        id := keccak256(0x00, 0x20)
        sstore(villagerSlot, id)

        let storedPacked := sload(add(villagerSlot, 1))
        let storedAuth := and(storedPacked, 0xff)
        if iszero(storedAuth) { revert(0, 0) }

        let defaultRolesMask := ROLE_SERF
        roles := add(defaultRolesMask, _contribution)
        if lt(roles, defaultRolesMask) { revert(0, 0) }

        let packed := or(storedAuth, shl(8, roles))
        sstore(add(villagerSlot, 1), packed)
    }
}
```

You can be thorough and go over the Solidity assembly code (which I also urge the reader to do), or you can be lazy like me and simply test what the function does when we pass different values to it.  

One weird thing I noticed immediately was that the `roles` variable is a {{ "uint8" | code_wrap: "language-solidity" }}. The good thing is that integer overflows and underflows are not checked in the assembly code.  

Sooo… what happens if we call this function with `_contribution` set to `255` (which is the max value of {{ "uint8" | code_wrap: "language-solidity" }})?  

The `defaultRolesMask` is `ROLE_SERF`, which by itself is `1 << 0`, meaning it's simply `1`. This means the overflow will actually set `roles` to `0`, thereby making us the **usurper**.

### Code that Brings Power
We have become the *usurper*. Here is the final code that achieves this:
```solidity
s = Setup(0x0); // Setup address goes here
eg = EldoriaGate(address(s.TARGET()));
bytes4 secret = 0xdeadfade;
eg.enter{value: 0xff}(secret);
```

But remember, <em>**he who seizes the crown by force can never wear it in peace**</em>.