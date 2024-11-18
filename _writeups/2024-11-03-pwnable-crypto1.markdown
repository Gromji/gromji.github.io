---
layout: post
title:  Crypto1
date:   2024-11-03 -0700
description: Pwnable.kr - Crypto1
tags: [Pwnable.kr, Crypto, Writeup]
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">Surely, nothing can go wrong by reusing IV in CBC mode?</span></div>
</div>

### Challenge overview

This challenge implements a log in system in which we are asked to give `ID` and `PW`. Apart from all of this, it stores three variables: *Key*, *IV* and *Cookie*.

*Key* and *IV* are used to encrypt/decrypt messages using **AES CBC mode**. We can see how this mode works by looking at the picture below.

<div style="background-color: white;">
<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/CBC_encryption.svg/2560px-CBC_encryption.svg.png" alt="AES CBC mode encryption" title="AES CBC mode encryption">
<img src="https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/CBC_decryption.svg/2560px-CBC_decryption.svg.png" alt="AES CBC mode decryption" title="AES CBC mode decryption">
</div>

After encrypting (*ID*, *PW*, *Cookie*) triplet, server decrypts this message (or packet as the challenge calls it) and checks that the following statement is true:

```python
hashlib.sha256(id+cookie).hexdigest() == pw and id == 'admin'
```

### Leaking the Cookie

Obviously, we want to login as admin to get the flag, but to do so we need to know what cookies is. If we somehow get the value of cookie variable then we can just send admin as *ID* and *SHA256* hash of *ID + Cookie* and we will login as admin and therefore get the flag.

Now the question is, how do we get the *Cookie*? Let's think about what flaws this encryption system has. Immediatley, we can see that *IV* is never randomly generated which it should be. Since it is not, same plaintext will give us same cipertext everytime. The way we can abuse this is to leak *Cookie* values byte by byte in a following manner (I'll explain this in general so that at least I don't spoil little details of the challenge):

Let's say we have encryption of \
\
`AAAAAAAAAAAAAAA (15 "A"s)` \
\
If before the encryption, secret value (*Cookie* in this case) is appended message becomes \
\
`AAAAAAAAAAAAAAAX` (where **X** is the first byte of *Cookie*) \
\
Since the challenge gives us the encryption of said message now we can iterate over all possible bytes \
\
`1234567890abcdefghijklmnopqrstuvwxyz-_` \
\
and test if encryption of our initial input plus the byte that we are testing is the same as the input plus one byte of the *Cookie*. This way we can leak *Cookie* byte by byte and therefore get the flag.
