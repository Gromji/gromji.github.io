---
layout: post
title:  Magic Animal Carousel
date:   2024-11-21 -0700
description: Ethernaut - MagicAnimal Carousel
tags: [Ethernaut, Blockchain, Writeup]
exclude: false
---

### Challenge overview

Challenge gives us a smart contract which has three functions: `setAnimalAndSpin`, `changeAnimal` and `encodeAnimalName`. Main functionality of the contract is that it tries to compact animal name, next index and animal owner into one slot. It does so by extracting/setting specific bits in each slot.

In my opinion, goal of the challenge seems a little bit blurry. Rule says that if you set and spin an animal it should not change. Initially, I thought maybe there is an animal set by somebody and I have to overwrite it but there is no animal at the start.

In reality, we have to make it so that if `setAnimalAndSpin` is called with a specific animal name and then queried the same animal, returned value should have different animal name from what was initially passed as an argument.

### Exploitation

After understanding what the goal is, exploitation is not that complex. Let's take a look at the following function:

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

Here we can see that `nextCrateId` is extracted form the slot corresponding to `currentCrateId` and then slot corresponding to `nextCrateId` is being set. Now the assumption when calculating `carousel[nextCrateId] & ~NEXT_ID_MASK` is that `carousel[nextCrateId]` is zero. If we manage to break that assumption, whenever someone tries to set animal and sping the animal, name will get xord with some value. We can easily break this assumption by calling `changeAnimal` on whatever `nextCrateId` will be.

### Extra Remarks

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

This function also allows us to overflow into `NEXT_ID_MASK` bits of the slot, because it is missing `require(encodedAnimal <= uint256(type(uint80).max), AnimalNameTooLong());` (unlike `setAnimalAndSpin`). I'm not sure what the intention here was but the contract can be exploited without leveraging this.