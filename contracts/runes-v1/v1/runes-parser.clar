;; ============================================================================
;; Runes Protocol Parser for Clarity
;; ============================================================================
;;
;; This contract provides parsing functionality for Bitcoin Runes protocol
;; runestones. It can decode OP_RETURN outputs containing Runes transfers,
;; mints, and etches.
;;
;; Runes Protocol Spec: https://github.com/ordinals/ord/blob/master/docs/src/runes.md
;;
;; A runestone is stored in a Bitcoin transaction output with:
;;   OP_RETURN (0x6a) + OP_13 (0x5d) + [LEB128-encoded data]
;;
;; This implementation focuses on the most common use case: parsing transfer
;; edicts to validate incoming Runes payments.
;;
;; Version: 1.0.0
;; License: MIT
;; ============================================================================

;; ============================================================================
;; Constants
;; ============================================================================

;; Magic bytes for Runes protocol
(define-constant OP-RETURN 0x6a)
(define-constant OP-13 0x5d)

;; Runestone field tags (used to identify different parts of the runestone)
(define-constant TAG-BODY u0)           ;; Edicts follow
(define-constant TAG-FLAGS u2)          ;; Etching flags
(define-constant TAG-RUNE u4)           ;; Rune name (for etching)
(define-constant TAG-PREMINE u6)        ;; Premine amount
(define-constant TAG-CAP u8)            ;; Mint cap
(define-constant TAG-AMOUNT u10)        ;; Mint amount per tx
(define-constant TAG-HEIGHT-START u12)  ;; Mint start height
(define-constant TAG-HEIGHT-END u14)    ;; Mint end height
(define-constant TAG-OFFSET-START u16)  ;; Mint start offset
(define-constant TAG-OFFSET-END u18)    ;; Mint end offset
(define-constant TAG-MINT u20)          ;; Mint command (specifies rune ID)
(define-constant TAG-POINTER u22)       ;; Default output for unallocated runes
(define-constant TAG-CENOTAPH u126)     ;; Marks malformed runestone
(define-constant TAG-DIVISIBILITY u1)   ;; Rune divisibility
(define-constant TAG-SPACERS u3)        ;; Rune name spacers
(define-constant TAG-SYMBOL u5)         ;; Rune symbol
(define-constant TAG-NOP u127)          ;; No operation (reserved)

;; Error codes
(define-constant ERR-NOT-OP-RETURN (err u2000))
(define-constant ERR-NOT-RUNES-MAGIC (err u2001))
(define-constant ERR-PARSE-FAILED (err u2002))
(define-constant ERR-NO-EDICTS (err u2003))
(define-constant ERR-WRONG-RUNE-ID (err u2004))
(define-constant ERR-WRONG-OUTPUT (err u2005))
(define-constant ERR-INVALID-TAG (err u2006))
(define-constant ERR-CENOTAPH (err u2007))
(define-constant ERR-SCRIPT-TOO-SHORT (err u2008))

;; ============================================================================
;; LEB128 Decoder (inline minimal version)
;; ============================================================================
;; Note: In production, you'd import this from the separate leb128-decoder.clar

(define-constant ERR-LEB128-OUT-OF-BOUNDS (err u1000))
(define-constant ERR-LEB128-OVERFLOW (err u1001))

(define-read-only (decode-leb128 
    (data (buff 4096)) 
    (start-offset uint)
  )
  (let (
      (result (fold decode-leb128-byte
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
        {
          data: data,
          offset: start-offset,
          value: u0,
          shift: u0,
          done: false,
          error: false
        }
      ))
    )
    (asserts! (not (get error result)) ERR-LEB128-OVERFLOW)
    (asserts! (get done result) ERR-LEB128-OUT-OF-BOUNDS)
    (ok {
      value: (get value result),
      next-offset: (get offset result)
    })
  )
)

(define-private (decode-leb128-byte 
    (byte-idx uint)
    (state {
      data: (buff 4096),
      offset: uint,
      value: uint,
      shift: uint,
      done: bool,
      error: bool
    })
  )
  (if (or (get done state) (get error state))
    state
    (match (element-at? (get data state) (get offset state))
      current-byte (let (
          (data-bits (bit-and current-byte 0x7f))
          (has-more (is-eq (bit-and current-byte 0x80) 0x80))
          (contribution (* data-bits (pow u2 (get shift state))))
          (new-value (+ (get value state) contribution))
        )
        {
          data: (get data state),
          offset: (+ (get offset state) u1),
          value: new-value,
          shift: (+ (get shift state) u7),
          done: (not has-more),
          error: false
        }
      )
      (merge state { 
        error: (not (get done state)),
        done: true 
      })
    )
  )
)

;; ============================================================================
;; Core Runes Parsing Functions
;; ============================================================================

;; Verify that a scriptPubKey is a valid Runes runestone
;; Returns true if it starts with OP_RETURN + OP_13
(define-read-only (is-runestone (script (buff 1376)))
  (and
    (is-eq (default-to 0x00 (element-at? script u0)) OP-RETURN)
    (is-eq (default-to 0x00 (element-at? script u1)) OP-13)
    (> (len script) u2)
  )
)

;; Parse a single edict from the runestone
;; An edict specifies: (rune-id, amount, output)
;; 
;; Rune ID encoding:
;;   - First edict: (block, tx-index)
;;   - Subsequent edicts: (block-delta, tx-index-delta)
;;
;; Parameters:
;;   - script: The OP_RETURN scriptPubKey
;;   - offset: Current position in the script
;;   - previous-block: Previous rune's block (for delta decoding)
;;   - previous-tx: Previous rune's tx index (for delta decoding)
;;
;; Returns:
;;   (ok {
;;     block: uint,
;;     tx-index: uint,
;;     amount: uint,
;;     output: uint,
;;     next-offset: uint
;;   })
(define-read-only (parse-edict
    (script (buff 1376))
    (offset uint)
    (previous-block uint)
    (previous-tx uint)
  )
  (let (
      ;; Decode block delta
      (block-delta-result (try! (decode-leb128 script offset)))
      (block-delta (get value block-delta-result))
      
      ;; Decode tx index delta
      (tx-delta-result (try! (decode-leb128 script (get next-offset block-delta-result))))
      (tx-delta (get value tx-delta-result))
      
      ;; Decode amount
      (amount-result (try! (decode-leb128 script (get next-offset tx-delta-result))))
      (amount (get value amount-result))
      
      ;; Decode output
      (output-result (try! (decode-leb128 script (get next-offset amount-result))))
      (output (get value output-result))
      
      ;; Calculate absolute rune ID from deltas
      (new-block (+ previous-block block-delta))
      (new-tx (if (is-eq block-delta u0)
        (+ previous-tx tx-delta)
        tx-delta
      ))
    )
    (ok {
      block: new-block,
      tx-index: new-tx,
      amount: amount,
      output: output,
      next-offset: (get next-offset output-result)
    })
  )
)

;; ============================================================================
;; Simplified Parser for Single Transfer
;; ============================================================================

;; Parse a simple Runes transfer with ONE edict
;; This is the most common use case for accepting Runes payments
;;
;; Validates:
;;   1. Script is a valid runestone (OP_RETURN + OP_13)
;;   2. Contains edicts (tag = 0)
;;   3. Rune ID matches expected
;;   4. Transfer is to expected output
;;
;; Parameters:
;;   - script: The OP_RETURN scriptPubKey
;;   - expected-block: Expected rune block number
;;   - expected-tx: Expected rune tx index
;;   - expected-output: Expected output index (usually u1)
;;
;; Returns:
;;   (ok amount) - The amount of runes transferred
;;
;; Example:
;;   ;; Parse 100 DOG runes to output 1
;;   (parse-simple-transfer script u2585442 u1183 u1)
;;   => (ok u100)
(define-read-only (parse-simple-transfer
    (script (buff 1376))
    (expected-block uint)
    (expected-tx uint)
    (expected-output uint)
  )
  (let (
      (script-len (len script))
    )
    ;; Validate minimum length
    (asserts! (>= script-len u3) ERR-SCRIPT-TOO-SHORT)
    
    ;; Verify magic bytes
    (asserts! (is-eq (unwrap! (element-at? script u0) ERR-NOT-OP-RETURN) OP-RETURN) 
      ERR-NOT-OP-RETURN)
    (asserts! (is-eq (unwrap! (element-at? script u1) ERR-NOT-RUNES-MAGIC) OP-13) 
      ERR-NOT-RUNES-MAGIC)
    
    ;; Parse tag (should be 0 for edicts)
    (let (
        (tag-result (try! (decode-leb128 script u2)))
        (tag (get value tag-result))
      )
      ;; Verify it's an edict tag
      (asserts! (is-eq tag TAG-BODY) ERR-NO-EDICTS)
      
      ;; Parse the edict (first edict starts with absolute block/tx)
      (let ((edict (try! (parse-edict script (get next-offset tag-result) u0 u0))))
        ;; Validate rune ID
        (asserts! (is-eq (get block edict) expected-block) ERR-WRONG-RUNE-ID)
        (asserts! (is-eq (get tx-index edict) expected-tx) ERR-WRONG-RUNE-ID)
        
        ;; Validate output
        (asserts! (is-eq (get output edict) expected-output) ERR-WRONG-OUTPUT)
        
        ;; Return amount
        (ok (get amount edict))
      )
    )
  )
)

;; ============================================================================
;; Helper: Get Output with Runestone
;; ============================================================================

;; Find the OP_RETURN output containing a runestone in a transaction
;; Returns the output index and scriptPubKey
;;
;; This is useful when parsing Bitcoin transactions to find the runestone
(define-read-only (find-runestone-output 
    (outputs (list 50 {
      value: uint,
      scriptPubKey: (buff 1376)
    }))
  )
  (let (
      (result (fold check-output-for-runestone 
        outputs
        {
          found: false,
          index: u0,
          current-index: u0,
          script: 0x
        }
      ))
    )
    (if (get found result)
      (ok {
        index: (get index result),
        script: (get script result)
      })
      ERR-NO-EDICTS
    )
  )
)

(define-private (check-output-for-runestone
    (output {
      value: uint,
      scriptPubKey: (buff 1376)
    })
    (state {
      found: bool,
      index: uint,
      current-index: uint,
      script: (buff 1376)
    })
  )
  (if (get found state)
    state
    (if (is-runestone (get scriptPubKey output))
      {
        found: true,
        index: (get current-index state),
        current-index: (+ (get current-index state) u1),
        script: (get scriptPubKey output)
      }
      {
        found: false,
        index: (get index state),
        current-index: (+ (get current-index state) u1),
        script: (get script state)
      }
    )
  )
)

;; ============================================================================
;; Integration Helper for Your Swap Contract
;; ============================================================================

;; Parse Runes from a Bitcoin transaction output
;; This is what you'd call from your swap-btc-to-aibtc function
;;
;; Parameters:
;;   - wtx: Parsed witness transaction (from clarity-bitcoin-lib)
;;   - expected-rune-block: The rune's block number
;;   - expected-rune-tx: The rune's tx index
;;   - expected-output-idx: Which output should receive the runes (usually u1)
;;
;; Returns:
;;   (ok rune-amount) if valid transfer found
;;
;; Example usage in your swap function:
;;   (let ((rune-amount (try! (parse-runes-from-wtx 
;;       wtx 
;;       DOG-RUNE-BLOCK 
;;       DOG-RUNE-TX 
;;       u1))))
;;     ;; rune-amount now contains how many DOG runes were sent
;;     ;; continue with your swap logic...
;;   )
(define-read-only (parse-runes-from-wtx
    (wtx {
      version: uint,
      segwit-marker: uint,
      segwit-version: uint,
      ins: (list 50 {
        outpoint: {
          hash: (buff 32),
          index: uint
        },
        scriptSig: (buff 1376),
        sequence: uint
      }),
      outs: (list 50 {
        value: uint,
        scriptPubKey: (buff 1376)
      }),
      txid: (optional (buff 32)),
      witnesses: (list 50 (list 13 (buff 1376))),
      locktime: uint
    })
    (expected-rune-block uint)
    (expected-rune-tx uint)
    (expected-output-idx uint)
  )
  (let (
      ;; Find the runestone output
      (runestone (try! (find-runestone-output (get outs wtx))))
      (script (get script runestone))
    )
    ;; Parse the transfer
    (parse-simple-transfer 
      script 
      expected-rune-block 
      expected-rune-tx 
      expected-output-idx
    )
  )
)

;; ============================================================================
;; Test Functions
;; ============================================================================

;; Test parsing a simple DOG rune transfer
;; This creates a minimal valid runestone for testing
(define-read-only (test-parse-dog-transfer)
  (let (
      ;; OP_RETURN + OP_13 + tag(0) + block(2585442) + tx(1183) + amount(100) + output(1)
      ;; In hex: 0x6a 0x5d 0x00 0x82b49d01 0x9f09 0x64 0x01
      (test-script 0x6a5d0082b49d019f096401)
    )
    (parse-simple-transfer test-script u2585442 u1183 u1)
  )
)

;; Test error cases
(define-read-only (test-error-cases)
  (let (
      (bad-magic 0x6a5c0082b49d019f096401)  ;; Wrong OP code
      (wrong-rune 0x6a5d0001020304)          ;; Different rune ID
      (not-op-return 0x0082b49d019f096401)   ;; Missing OP_RETURN
    )
    {
      bad-magic: (parse-simple-transfer bad-magic u2585442 u1183 u1),
      wrong-rune: (parse-simple-transfer wrong-rune u2585442 u1183 u1),
      not-op-return: (parse-simple-transfer not-op-return u2585442 u1183 u1)
    }
  )
)

;; Test with real Bitcoin transaction structure
(define-read-only (test-full-transaction-parse)
  (let (
      ;; Mock Bitcoin transaction with Runes transfer
      (mock-wtx {
        version: u2,
        segwit-marker: u0,
        segwit-version: u1,
        ins: (list),
        outs: (list
          ;; Output 0: OP_RETURN with runestone
          {
            value: u0,
            scriptPubKey: 0x6a5d0082b49d019f096401
          }
          ;; Output 1: Recipient address (your pool)
          {
            value: u100000,
            scriptPubKey: 0x76a914000000000000000000000000000000000000000088ac
          }
        ),
        txid: none,
        witnesses: (list),
        locktime: u0
      })
    )
    (parse-runes-from-wtx mock-wtx u2585442 u1183 u1)
  )
)

;; ============================================================================
;; Documentation & Examples
;; ============================================================================

;; Example: DOG Rune (DOG•GO•TO•THE•MOON)
;; Rune ID: 2585442:1183
;; Block: 2585442 (0x82B49D01 in LEB128)
;; TX Index: 1183 (0x9F09 in LEB128)
;;
;; A transfer of 100 DOG to output 1 encodes as:
;; 0x6a 0x5d 0x00 0x82b49d01 0x9f09 0x64 0x01
;; │    │    │    │          │      │    └─ Output index: 1
;; │    │    │    │          │      └────── Amount: 100
;; │    │    │    │          └───────────── TX index: 1183
;; │    │    │    └──────────────────────── Block: 2585442
;; │    │    └───────────────────────────── Tag: 0 (edicts)
;; │    └────────────────────────────────── OP_13 (Runes magic)
;; └─────────────────────────────────────── OP_RETURN
