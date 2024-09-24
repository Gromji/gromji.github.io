---
layout: post
title:  "Play to Earn"
date:   2024-08-25 14:21:29 -0700
description: Can you recover the burnt tokens?
tags: SekaiCTF Blockchain
exclude: false
---

<div class="spoiler-container">
  <div>Hint:&nbsp;<span class="spoiler-text">Check out ecrecover!</span></div>
</div>

We are given three files ArcadeMachine.sol, Coin.sol and Setup.sol. As it can be seen from the Setup contract, we need at least 13.37 ether to get the flag. What can be seen from the constructor is that 19 of the 20 ether gets deposited by the Setup contract. Then, ArcadeMachine contract gets approved to spend 19 ether and finally, ArcadeMachine contract tries to burn 19 ether by sending it to **address(0)**.

Well, goal should be simple, we need to recover "burnt" 19 ether. After thorough investigation of the Coin.sol we can see a suspicious looking function which *permits* someone use someone else's ether (similar to *approve* function).

<body class="bg">
<pre class="chroma"><code class="solidity"><span class="line"><span class="cl"><span class="kd">function</span> <span class="nf">permit</span><span class="p">(</span>
</span></span><span class="line"><span class="cl">  <span class="kt">address</span> <span class="n">owner</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">address</span> <span class="n">spender</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">uint256</span> <span class="n">value</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">uint256</span> <span class="n">deadline</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">uint8</span> <span class="n">v</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">bytes32</span> <span class="n">r</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">  <span class="kt">bytes32</span> <span class="n">s</span>
</span></span><span class="line"><span class="cl"><span class="p">)</span> <span class="k">external</span> <span class="p">{</span>
</span></span><span class="line"><span class="cl">  <span class="nb">require</span><span class="p">(</span><span class="nb">block</span><span class="p">.</span><span class="nb">timestamp</span> <span class="o">&lt;=</span> <span class="n">deadline</span><span class="p">,</span> <span class="s">&#34;signature expired&#34;</span><span class="p">);</span>
</span></span><span class="line"><span class="cl">  <span class="kt">bytes32</span> <span class="n">structHash</span> <span class="o">=</span> <span class="nb">keccak256</span><span class="p">(</span>
</span></span><span class="line"><span class="cl">    <span class="nb">abi</span><span class="p">.</span><span class="nb">encode</span><span class="p">(</span>
</span></span><span class="line"><span class="cl">      <span class="n">PERMIT_TYPEHASH</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">      <span class="n">owner</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">      <span class="n">spender</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">      <span class="n">value</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">      <span class="n">nonces</span><span class="p">[</span><span class="n">owner</span><span class="p">]</span><span class="o">++</span><span class="p">,</span>
</span></span><span class="line"><span class="cl">      <span class="n">deadline</span>
</span></span><span class="line"><span class="cl">      <span class="p">)</span>
</span></span><span class="line"><span class="cl">  <span class="p">);</span>
</span></span><span class="line"><span class="cl">  <span class="kt">bytes32</span> <span class="n">h</span> <span class="o">=</span> <span class="nb">_hashTypedDataV4</span><span class="p">(</span><span class="n">structHash</span><span class="p">);</span>
</span></span><span class="line"><span class="cl">  <span class="kt">address</span> <span class="n">signer</span> <span class="o">=</span> <span class="nb">ecrecover</span><span class="p">(</span><span class="n">h</span><span class="p">,</span> <span class="n">v</span><span class="p">,</span> <span class="n">r</span><span class="p">,</span> <span class="n">s</span><span class="p">);</span>
</span></span><span class="line"><span class="cl">  <span class="nb">require</span><span class="p">(</span><span class="n">signer</span> <span class="o">==</span> <span class="n">owner</span><span class="p">,</span> <span class="s">&#34;invalid signer&#34;</span><span class="p">);</span>
</span></span><span class="line"><span class="cl">  <span class="n">allowance</span><span class="p">[</span><span class="n">owner</span><span class="p">][</span><span class="n">spender</span><span class="p">]</span> <span class="o">=</span> <span class="n">value</span><span class="p">;</span>
</span></span><span class="line"><span class="cl">  <span class="n">emit</span> <span class="n">Approval</span><span class="p">(</span><span class="n">owner</span><span class="p">,</span> <span class="n">spender</span><span class="p">,</span> <span class="n">value</span><span class="p">);</span>
</span></span><span class="line"><span class="cl"><span class="p">}</span></span></span></code></pre>
</body>

This function basically just asks user to provide a signature (v, r, s) for the data, it then recovers the signer using **ecrecover** and checks that signer and owner are the same person. This all seems good, but there is one flaw in this code. If we take a look at what ecrecover returns, we will find that upon failure, ecrecover returns **0**. One may ask, yes but how does that help in this situation? Well, now we can act like we have data signed by **address(0)** and get approval on using **address(0)**'s funds. After this it becomes straightforward.

