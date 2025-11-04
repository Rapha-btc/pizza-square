# Reverse Engineering a Simple Runes Transfer

Let me show you what a minimal runes transfer looks like at the data level.

## Simple Transfer: 100 DOG•GO•TO•THE•MOON to Your Address

### Bitcoin Transaction Structure:

```
Input 0: UTXO containing 100 DOG runes + some BTC
Output 0: OP_RETURN (the runestone)
Output 1: Your address (receives the 100 DOG runes + some BTC dust)
Output 2: Change address (if any)
```

### The OP_RETURN Data (Runestone):

```
OP_RETURN (0x6a)
OP_13 (0x5d)
[LEB128 encoded data]
```

### What's in the LEB128 Data:

For a **simple transfer with one edict**, you'd encode:

```
Tag: 0 (edicts follow)
Rune ID (block delta): e.g., 2585442 (if DOG was etched in block 2585442)
Rune ID (tx index): e.g., 1183
Amount: 100 (in atomic units - depends on divisibility)
Output: 1 (send to output index 1)
```

### Actual Hex Example:

Here's what a real simple DOG transfer might look like:

```
6a 5d
00                    // tag 0 = edicts
82 b4 9d 01          // block delta (LEB128: 2585442)
9f 09                // tx index (LEB128: 1183)
64                   // amount (LEB128: 100)
01                   // output (LEB128: 1)
```

## Making it SIMPLEST to Parse

Here's the **absolutely minimal** runestone for your use case:

### Option 1: Single Edict to Output 1 (Your Pool)

```clarity
// Simplest possible runestone structure:
// - One edict only
// - Always to output index 1
// - Known rune ID (you hardcode it)

(define-constant DOG-RUNE-BLOCK u2585442)
(define-constant DOG-RUNE-TX u1183)

(define-read-only (parse-simple-runes-transfer (script (buff 1376)))
  (let (
      ;; Verify OP_RETURN + OP_13
      (byte0 (unwrap! (element-at? script u0) ERR-NOT-RUNES))
      (byte1 (unwrap! (element-at? script u1) ERR-NOT-RUNES))
    )
    (asserts! (is-eq byte0 0x6a) ERR-NOT-OP-RETURN)
    (asserts! (is-eq byte1 0x5d) ERR-NOT-RUNES-MAGIC)

    ;; Parse tag (should be 0 for edicts)
    (let (
        (tag (unwrap! (element-at? script u2) ERR-PARSE))
        (offset u3)
      )
      (asserts! (is-eq tag 0x00) ERR-NOT-EDICT)

      ;; Decode block delta
      (let ((block-result (unwrap! (decode-leb128 script offset) ERR-DECODE)))
        ;; Verify it matches expected rune
        (asserts! (is-eq (get value block-result) DOG-RUNE-BLOCK) ERR-WRONG-RUNE)

        ;; Decode tx index
        (let ((tx-result (unwrap! (decode-leb128 script (get next-offset block-result)) ERR-DECODE)))
          (asserts! (is-eq (get value tx-result) DOG-RUNE-TX) ERR-WRONG-RUNE)

          ;; Decode amount (THIS IS WHAT YOU CARE ABOUT)
          (let ((amount-result (unwrap! (decode-leb128 script (get next-offset tx-result)) ERR-DECODE)))

            ;; Decode output index (should be 1)
            (let ((output-result (unwrap! (decode-leb128 script (get next-offset amount-result)) ERR-DECODE)))
              (asserts! (is-eq (get value output-result) u1) ERR-WRONG-OUTPUT)

              ;; Return just the amount
              (ok (get value amount-result))
            )
          )
        )
      )
    )
  )
)
```

## LEB128 Decoder You Need:## How to Make It SIMPLEST on the Sender Side:

**Tell senders to structure their BTC transaction like this:**

```
Input 0: Their UTXO with DOG runes + BTC
Output 0: OP_RETURN with runestone (transfer edict)
Output 1: YOUR_POOL_ADDRESS (receives runes + BTC)
Output 2: Their change address (optional)
```

**The runestone should contain:**

- Tag 0 (edicts)
- Single edict: `{rune_id: DOG, amount: X, output: 1}`
- NO pointer
- NO other edicts
- NO minting

This gives you a **fixed format** to parse - you always know:

1. Rune ID is hardcoded (DOG = block 2585442, tx 1183)
2. Output is always 1 (your pool)
3. Amount is the only variable

The key insight: **You control the deposit format** by only accepting this specific pattern and rejecting anything else!

Would you like me to integrate this into your existing `swap-btc-to-aibtc` function?
