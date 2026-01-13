---
layout: post
title:  Magic Animal Carousel
date:   2024-11-21 -0700
description: Ethernaut - MagicAnimal Carousel
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

## Challenge overview

The challenge gives us a smart contract with three functions: `setAnimalAndSpin`, `changeAnimal`, and `encodeAnimalName`. Its main functionality is to compact the animal name, next index, and animal owner into one slot by extracting or setting specific bits in each slot.

In my opinion, the goal of the challenge is a little blurry. The rule says that if you set and spin an animal it should not change. Initially, I thought there might be an animal set by someone that I had to overwrite, but there is no animal at the start.

In reality, we have to make it so that if `setAnimalAndSpin` is called with a specific animal name and the same animal is queried later, the returned value should have a different name from what was initially passed.

## Exploitation

After understanding the goal, exploitation is not that complex. Let's take a look at the following function:

```solidity
function setAnimalAndSpin(string calldata animal) external {
  uint256 encodedAnimal = encodeAnimalName(animal) >> 16;
  uint256 nextCrateId = (carousel[currentCrateId] & NEXT_ID_MASK) >> 160;

  require(encodedAnimal <= uint256(type(uint80).max), AnimalNameTooLong());
  carousel[nextCrateId] = (carousel[nextCrateId] & ~NEXT_ID_MASK) ^ (encodedAnimal << 160 + 16)
    | ((nextCrateId + 1) % MAX_CAPACITY) << 160 | uint160(msg.sender);

  currentCrateId = nextCrateId;
}
```

Here we see that `nextCrateId` is extracted from the slot corresponding to `currentCrateId`, and then the slot corresponding to `nextCrateId` is set. The calculation `carousel[nextCrateId] & ~NEXT_ID_MASK` assumes `carousel[nextCrateId]` is zero. If we break that assumption, whenever someone sets an animal and spins it, the name will get XORed with some value. We can easily break this assumption by calling `changeAnimal` on whatever `nextCrateId` will be.

## Extra Remarks

```solidity
function changeAnimal(string calldata animal, uint256 crateId) external {
  address owner = address(uint160(carousel[crateId] & OWNER_MASK));
  if (owner != address(0)) {
      require(msg.sender == owner);
  }
  uint256 encodedAnimal = encodeAnimalName(animal);
  if (encodedAnimal != 0) {
      // Replace animal
      carousel[crateId] =
          (encodedAnimal << 160) | (carousel[crateId] & NEXT_ID_MASK) | uint160(msg.sender); 
  } else {
      // If no animal specified keep same animal but clear owner slot
      carousel[crateId]= (carousel[crateId] & (ANIMAL_MASK | NEXT_ID_MASK));
  }
}
```

This function also allows us to overflow into the `NEXT_ID_MASK` bits of the slot because it is missing `require(encodedAnimal <= uint256(type(uint80).max), AnimalNameTooLong());` (unlike `setAnimalAndSpin`). I'm not sure what the intention was here, but the contract can be exploited without leveraging this.