# Runes Protocol Parser for Clarity

Complete implementation of LEB128 decoding and Runes protocol parsing for Stacks smart contracts.

## 📦 What's Included

- **leb128-decoder.clar** - Production-ready LEB128 decoder with full error handling
- **runes-parser.clar** - Complete Runes protocol parser for runestones
- **runes-tests.clar** - Comprehensive test suite with real-world examples
- **integration-example.clar** - Step-by-step guide to add Runes to your swap contract

## 🎯 Use Case

You have a BTC → sBTC → AI token swap contract. Users want to pay with **Runes** (fungible Bitcoin tokens like DOG•GO•TO•THE•MOON) instead of just BTC.

This implementation lets you:
1. ✅ Parse Runes transfers from Bitcoin OP_RETURN outputs
2. ✅ Validate which Runes you accept
3. ✅ Extract the amount sent
4. ✅ Execute swaps based on Runes instead of BTC

## 🚀 Quick Start

### 1. Understanding the Flow

```
User sends Bitcoin transaction:
┌─────────────────────────────────────┐
│ Input: UTXO with 100 DOG runes      │
│                                     │
│ Output 0: OP_RETURN                 │
│   - Your payload (Stacks address)   │
│   - Runestone: 100 DOG → output 1   │
│                                     │
│ Output 1: Your pool (gets DOG+BTC) │
│ Output 2: Change                    │
└─────────────────────────────────────┘
                  ↓
Your Clarity contract parses & validates:
┌─────────────────────────────────────┐
│ 1. Verify BTC tx mined ✓            │
│ 2. Parse runestone ✓                │
│ 3. Check rune ID (DOG?) ✓           │
│ 4. Extract amount: 100 ✓            │
│ 5. Calculate: 100 × rate = tokens   │
│ 6. Execute swap ✓                   │
└─────────────────────────────────────┘
```

### 2. Add to Your Contract

```clarity
;; Step 1: Copy the LEB128 decoder
;; (from leb128-decoder.clar - the decode-leb128 function)

;; Step 2: Define accepted runes
(define-constant DOG-RUNE-BLOCK u2585442)
(define-constant DOG-RUNE-TX u1183)

;; Step 3: Parse runes in your swap function
(define-public (swap-btc-to-aibtc ...)
  (let (
      ;; Your existing BTC verification...
      
      ;; NEW: Try to parse runes
      (runes-data (parse-runes-from-wtx 
        wtx 
        DOG-RUNE-BLOCK 
        DOG-RUNE-TX 
        u1  ;; output index of your pool
      ))
    )
    ;; If runes found, use that amount
    ;; Otherwise, use BTC amount (existing logic)
    ...
  )
)
```

## 📖 How It Works

### LEB128 Encoding

Runes uses **LEB128** (Little Endian Base 128) to compress integers:

```
Value: 100
Binary: 01100100
LEB128: 0x64 (1 byte)

Value: 2585442 (DOG block height)
Binary: 00100111 01001011 10011101
LEB128: 0x82 0xB4 0x9D 0x01 (4 bytes)
         └──┬──┘ └──┬──┘ └──┬──┘ └──┬──┘
         byte 1  byte 2  byte 3  byte 4
         
Each byte:
- Bits 0-6: Data (7 bits)
- Bit 7: Continuation (1 = more bytes, 0 = last)
```

### Runestone Structure

```
OP_RETURN (0x6a)
OP_13 (0x5d)          ← Runes magic number
[LEB128 data]:
  ├─ Tag (0 = edicts)
  └─ Edict:
      ├─ Block number (LEB128)
      ├─ TX index (LEB128)
      ├─ Amount (LEB128)
      └─ Output (LEB128)
```

**Example: Transfer 100 DOG to output 1**
```
Hex: 0x6a 0x5d 0x00 0x82b49d01 0x9f09 0x64 0x01
     │    │    │    │          │      │    └─ Output: 1
     │    │    │    │          │      └────── Amount: 100
     │    │    │    │          └───────────── TX: 1183
     │    │    │    └──────────────────────── Block: 2585442
     │    │    └───────────────────────────── Tag: edicts
     │    └────────────────────────────────── OP_13
     └─────────────────────────────────────── OP_RETURN
```

## 🧪 Testing

### Run Basic Tests

```clarity
;; Test LEB128 decoder
(contract-call? .leb128-decoder test-decode-basic)
;; Should return: { test0: (ok u0), test100: (ok u100), ... }

;; Test Runes parsing
(contract-call? .runes-parser test-parse-dog-transfer)
;; Should return: (ok u100)
```

### Test with Real Transaction

```clarity
;; Create a mock Bitcoin transaction
(define-constant TEST-WTX {
  version: u2,
  segwit-marker: u0,
  segwit-version: u1,
  ins: (list),
  outs: (list
    {
      value: u0,
      scriptPubKey: 0x6a5d0082b49d019f096401  ;; Runestone
    }
    {
      value: u100000,
      scriptPubKey: 0x001400000000...  ;; Your pool
    }
  ),
  txid: none,
  witnesses: (list),
  locktime: u0
})

;; Parse it
(contract-call? .runes-parser parse-runes-from-wtx 
  TEST-WTX 
  u2585442  ;; DOG block
  u1183     ;; DOG tx
  u1        ;; output index
)
;; Should return: (ok u100)
```

## 🔧 Integration Steps

### For Your Existing Swap Contract

1. **Add Constants**
```clarity
(define-constant DOG-RUNE-BLOCK u2585442)
(define-constant DOG-RUNE-TX u1183)
(define-constant DOG-ENABLED true)
(define-constant DOG-EXCHANGE-RATE u1000)  ;; 1 DOG = 1000 AI tokens
```

2. **Add Runes Check**
```clarity
(define-public (swap-btc-to-aibtc ...)
  (let (
      ;; Existing: verify BTC transaction
      (tx-verified (try! (verify-btc-tx ...)))
      
      ;; NEW: Try to parse runes
      (maybe-runes (parse-runes-from-wtx wtx DOG-RUNE-BLOCK DOG-RUNE-TX u1))
    )
    ;; Branch on whether runes were found
    (match maybe-runes
      rune-amount (begin
        ;; Runes found! Use rune amount for swap
        (let ((ai-tokens (* rune-amount DOG-EXCHANGE-RATE)))
          (try! (execute-swap ai-tokens recipient))
          (ok { type: "runes", amount: rune-amount })
        )
      )
      error (begin
        ;; No runes, use BTC amount (existing logic)
        (try! (execute-btc-swap ...))
        (ok { type: "btc", amount: btc-amount })
      )
    )
  )
)
```

3. **Update Frontend**
```javascript
// When user selects DOG runes payment:
const runestone = encodeRunestone({
  runeId: { block: 2585442, tx: 1183 },
  amount: 100,
  output: 1  // Pool address
});

// Add to OP_RETURN output:
const opReturn = bitcoin.script.compile([
  bitcoin.opcodes.OP_RETURN,
  yourPayload,  // Existing: Stacks address, etc.
  bitcoin.opcodes.OP_13,
  runestone
]);
```

## 📊 Supported Runes

Currently configured for:

| Rune | ID | Block | TX | Status |
|------|-----|-------|-----|--------|
| DOG•GO•TO•THE•MOON | 2585442:1183 | 2585442 | 1183 | ✅ Ready |
| RSIC | 2510010:617 | 2510010 | 617 | 📝 Example |

Add more by defining constants and exchange rates.

## ⚠️ Important Notes

### 1. Output Index Matters
The runestone specifies which output receives the runes. You MUST verify:
```clarity
(asserts! (is-eq output u1) ERR-WRONG-OUTPUT)
```
Otherwise, runes might go to the wrong address!

### 2. Rune ID Validation
Always validate the rune ID matches what you expect:
```clarity
(asserts! (is-eq block DOG-RUNE-BLOCK) ERR-WRONG-RUNE)
(asserts! (is-eq tx DOG-RUNE-TX) ERR-WRONG-RUNE)
```
Don't accept random runes!

### 3. Multiple Edicts
This implementation handles **one edict** per runestone. Most transfers are single-edict. For multiple edicts, you'd need to extend the parser.

### 4. Cenotaphs
Malformed runestones are called "cenotaphs" and burn the runes. Our parser will fail on invalid runestones, which is safe - the transaction will be rejected.

## 🐛 Error Handling

```clarity
;; LEB128 errors
ERR-LEB128-OUT-OF-BOUNDS  ;; Tried to read past buffer end
ERR-LEB128-OVERFLOW       ;; Value too large (>10 bytes)

;; Runes errors  
ERR-NOT-OP-RETURN        ;; Not an OP_RETURN output
ERR-NOT-RUNES-MAGIC      ;; Missing OP_13
ERR-WRONG-RUNE-ID        ;; Unexpected rune
ERR-WRONG-OUTPUT         ;; Runes sent to wrong output
ERR-NO-EDICTS            ;; Runestone has no edicts
```

## 🎓 Learning Resources

- [Runes Official Docs](https://docs.ordinals.com/runes.html)
- [Runes GitHub Spec](https://github.com/ordinals/ord/blob/master/docs/src/runes.md)
- [LEB128 on Wikipedia](https://en.wikipedia.org/wiki/LEB128)
- [Clarity Bitcoin Lib](https://github.com/friedger/clarity-bitcoin)

## 🤝 Credits

Based on:
- Runes protocol by Casey Rodarmor
- Clarity Bitcoin lib by Friedger
- Your existing swap contract

## 📜 License

MIT

## 🔮 Future Enhancements

- [ ] Support multiple edicts in one runestone
- [ ] Parse etching transactions (create new runes)
- [ ] Parse mint transactions
- [ ] Decode rune names from integers
- [ ] Support pointer field (alternative default output)
- [ ] Add cenotaph detection and handling
- [ ] Batch processing for multiple runes
- [ ] Rune balance tracking

## 💬 Need Help?

- Check `runes-tests.clar` for more examples
- Read `integration-example.clar` for detailed integration
- Review your existing `clarity-bitcoin-lib-v7` usage
- Test on Bitcoin Testnet first!

## 🚢 Deployment Checklist

- [ ] Test LEB128 decoder with all test cases
- [ ] Test Runes parser with DOG examples
- [ ] Verify integration with your swap contract
- [ ] Test on Bitcoin Testnet
- [ ] Document rune acceptance policy for users
- [ ] Update frontend to support runes
- [ ] Monitor first mainnet transactions
- [ ] Set up alerts for unsupported runes
- [ ] Document exchange rates
- [ ] Create user guide

---

**Ready to accept Runes payments in your Stacks contract! 🎉**

For questions, check the test suite or integration example files.
