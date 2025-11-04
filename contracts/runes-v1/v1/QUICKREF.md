# Runes Parser Quick Reference

## 🎯 Core Function Calls

### Parse Simple Runes Transfer
```clarity
(parse-simple-transfer 
  script          ;; (buff 1376) - The OP_RETURN scriptPubKey
  expected-block  ;; uint - Rune block number
  expected-tx     ;; uint - Rune tx index
  expected-output ;; uint - Expected output (usually u1)
)
;; Returns: (ok amount) or (err error-code)
```

### Parse from Bitcoin Transaction
```clarity
(parse-runes-from-wtx
  wtx              ;; Witness transaction from clarity-bitcoin-lib
  expected-block   ;; uint - Rune block number
  expected-tx      ;; uint - Rune tx index  
  expected-output  ;; uint - Expected output
)
;; Returns: (ok amount) or (err error-code)
```

### Decode LEB128 Integer
```clarity
(decode-leb128
  data         ;; (buff 4096) - Buffer containing LEB128
  start-offset ;; uint - Where to start reading
)
;; Returns: (ok { value: uint, next-offset: uint })
```

## 📋 Common Rune IDs

```clarity
;; DOG•GO•TO•THE•MOON
(define-constant DOG-BLOCK u2585442)  ;; 0x82b49d01
(define-constant DOG-TX u1183)        ;; 0x9f09

;; RSIC
(define-constant RSIC-BLOCK u2510010) ;; 0xeae49801
(define-constant RSIC-TX u617)        ;; 0x8904
```

## 🔢 LEB128 Quick Decode Table

| Decimal | Hex | Bytes | LEB128 Hex |
|---------|-----|-------|------------|
| 0 | 0x00 | 1 | 0x00 |
| 1 | 0x01 | 1 | 0x01 |
| 100 | 0x64 | 1 | 0x64 |
| 127 | 0x7F | 1 | 0x7F |
| 128 | 0x80 | 2 | 0x80 0x01 |
| 256 | 0x100 | 2 | 0x80 0x02 |
| 1183 | 0x49F | 2 | 0x9F 0x09 |
| 16384 | 0x4000 | 3 | 0x80 0x80 0x01 |
| 2585442 | 0x2771E2 | 4 | 0x82 0xB4 0x9D 0x01 |

## 🧩 Runestone Structure

```
Byte  0: 0x6a (OP_RETURN)
Byte  1: 0x5d (OP_13)
Byte  2+: Tag (LEB128) - usually 0 for edicts
Byte  X+: Block number (LEB128)
Byte  Y+: TX index (LEB128)
Byte  Z+: Amount (LEB128)
Byte  W+: Output index (LEB128)
```

## 🎨 Example Runestones

### Transfer 100 DOG to Output 1
```
Hex: 6a5d0082b49d019f096401
     │ │ │ │       │    │  └─ Output: 1
     │ │ │ │       │    └──── Amount: 100
     │ │ │ │       └───────── TX: 1183
     │ │ │ └───────────────── Block: 2585442
     │ │ └─────────────────── Tag: 0
     │ └───────────────────── OP_13
     └─────────────────────── OP_RETURN
```

### Transfer 1000 DOG to Output 2
```
Hex: 6a5d0082b49d019f09e80702
                      └──┬──┘
                      1000  output 2
```

## ⚠️ Error Codes

| Code | Constant | Meaning |
|------|----------|---------|
| 1000 | ERR-LEB128-OUT-OF-BOUNDS | Read past buffer |
| 1001 | ERR-LEB128-OVERFLOW | Value > 10 bytes |
| 2000 | ERR-NOT-OP-RETURN | Not OP_RETURN |
| 2001 | ERR-NOT-RUNES-MAGIC | Missing OP_13 |
| 2004 | ERR-WRONG-RUNE-ID | Unexpected rune |
| 2005 | ERR-WRONG-OUTPUT | Wrong output index |

## 🔨 Integration Pattern

```clarity
;; 1. Define your accepted runes
(define-constant MY-RUNE-BLOCK u2585442)
(define-constant MY-RUNE-TX u1183)

;; 2. In your swap function:
(match (parse-runes-from-wtx wtx MY-RUNE-BLOCK MY-RUNE-TX u1)
  rune-amount (begin
    ;; Got runes! Do runes swap
    (swap-runes rune-amount recipient)
  )
  error (begin
    ;; No runes, do BTC swap
    (swap-btc btc-amount recipient)
  )
)
```

## 🧪 Quick Tests

```clarity
;; Test decoder
(decode-leb128 0x64 u0)
;; => (ok { value: u100, next-offset: u1 })

(decode-leb128 0x82b49d01 u0)
;; => (ok { value: u2585442, next-offset: u4 })

;; Test parser
(parse-simple-transfer 
  0x6a5d0082b49d019f096401 
  u2585442 
  u1183 
  u1
)
;; => (ok u100)
```

## 📐 LEB128 Encoding Formula

```
For each byte:
  data_bits = value & 0x7F       // Lower 7 bits
  has_more = (value > 127)       // More bytes needed?
  byte = data_bits | (has_more ? 0x80 : 0x00)
  value = value >> 7             // Shift for next byte
```

## 🔄 Decoding Formula

```clarity
value = 0
shift = 0
for each byte:
  data_bits = byte & 0x7F
  value += data_bits * (2 ^ shift)
  shift += 7
  if (byte & 0x80) == 0:
    break  // Last byte
```

## 🎯 Validation Checklist

When parsing a runestone:
- ✅ Check byte 0 == 0x6a (OP_RETURN)
- ✅ Check byte 1 == 0x5d (OP_13)
- ✅ Parse tag == 0 (edicts)
- ✅ Decode block matches expected
- ✅ Decode tx matches expected
- ✅ Decode amount > 0
- ✅ Decode output matches pool

## 💡 Tips

1. **Always validate rune ID** - Don't accept random runes
2. **Check output index** - Ensure runes go to your pool
3. **Handle no-runes case** - Transaction might just be BTC
4. **Test with small amounts first** - On testnet
5. **Monitor gas costs** - LEB128 decoding uses fold

## 📞 Common Questions

**Q: Can one transaction have multiple runes?**
A: Yes, via multiple edicts. Current parser handles one.

**Q: What if wrong rune is sent?**
A: Parser returns error, transaction rejected.

**Q: Do I need to track rune balances?**
A: Not on-chain. Runes live on Bitcoin.

**Q: What about divisibility?**
A: Check rune's divisibility and adjust amounts.

**Q: Can users send partial runes?**
A: Yes, if divisibility > 0 (e.g., 1.5 DOG).

## 🚀 Performance Notes

- **LEB128 decode**: ~200-500 cycles per integer
- **Single edict**: ~1000-2000 cycles
- **Full transaction**: ~5000-10000 cycles
- **Optimized for**: Values < 4 bytes (most cases)

## 📦 Files Included

1. `leb128-decoder.clar` - Core LEB128 implementation
2. `runes-parser.clar` - Runestone parser
3. `runes-tests.clar` - Test suite
4. `integration-example.clar` - Integration guide
5. `README.md` - Full documentation
6. `QUICKREF.md` - This file

---

**Keep this handy while coding! 🚀**
