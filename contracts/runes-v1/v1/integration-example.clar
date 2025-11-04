;; ============================================================================
;; Integration Example: Adding Runes Support to swap-btc-to-aibtc
;; ============================================================================
;;
;; This file shows how to integrate Runes parsing into your existing
;; swap-btc-to-aibtc contract. It demonstrates the minimal changes needed
;; to support Runes payments alongside BTC.
;;
;; Key Changes:
;; 1. Add Runes validation to transaction parsing
;; 2. Extract rune amount alongside BTC amount
;; 3. Use rune amount for swap calculations
;; 4. Track accepted runes
;;
;; ============================================================================

;; Import existing contracts (adjust paths)
;; (use-trait bitcoin-lib 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.clarity-bitcoin-lib-v7)
;; (use-trait runes-parser .runes-parser)

;; ============================================================================
;; Constants for Accepted Runes
;; ============================================================================

;; DOG rune configuration
(define-constant DOG-RUNE-BLOCK u2585442)
(define-constant DOG-RUNE-TX u1183)
(define-constant DOG-RUNE-ENABLED true)

;; RSIC rune configuration (example of multiple runes)
(define-constant RSIC-RUNE-BLOCK u2510010)
(define-constant RSIC-RUNE-TX u617)
(define-constant RSIC-RUNE-ENABLED false)  ;; Disabled for now

;; Error codes
(define-constant ERR-RUNES-DISABLED (err u3000))
(define-constant ERR-UNSUPPORTED-RUNE (err u3001))
(define-constant ERR-NO-RUNES-FOUND (err u3002))

;; ============================================================================
;; Helper: Check if Rune is Accepted
;; ============================================================================

(define-read-only (is-accepted-rune (block uint) (tx uint))
  (or
    ;; Check if it's DOG and enabled
    (and 
      (is-eq block DOG-RUNE-BLOCK)
      (is-eq tx DOG-RUNE-TX)
      DOG-RUNE-ENABLED
    )
    ;; Check if it's RSIC and enabled
    (and 
      (is-eq block RSIC-RUNE-BLOCK)
      (is-eq tx RSIC-RUNE-TX)
      RSIC-RUNE-ENABLED
    )
    ;; Add more runes here as needed
  )
)

;; Get rune exchange rate (how many AI tokens per rune)
(define-read-only (get-rune-exchange-rate (block uint) (tx uint))
  (if (and (is-eq block DOG-RUNE-BLOCK) (is-eq tx DOG-RUNE-TX))
    u1000  ;; 1 DOG = 1000 AI tokens (example)
    (if (and (is-eq block RSIC-RUNE-BLOCK) (is-eq tx RSIC-RUNE-TX))
      u5000  ;; 1 RSIC = 5000 AI tokens (example)
      u0
    )
  )
)

;; ============================================================================
;; Modified Swap Function (Simplified Version)
;; ============================================================================

;; This is a SIMPLIFIED version showing the key changes
;; Your actual implementation will need to merge this with your existing logic

(define-public (swap-btc-with-runes-to-aibtc
    (height uint)
    (wtx {
      version: uint,
      segwit-marker: uint,
      segwit-version: uint,
      ins: (list 50 {
        outpoint: {
          hash: (buff 32),
          index: uint,
        },
        scriptSig: (buff 1376),
        sequence: uint,
      }),
      outs: (list 50 {
        value: uint,
        scriptPubKey: (buff 1376),
      }),
      txid: (optional (buff 32)),
      witnesses: (list 50 (list 13 (buff 1376))),
      locktime: uint,
    })
    (header (buff 80))
    (tx-index uint)
    (tree-depth uint)
    (wproof (list 14 (buff 32)))
    (witness-merkle-root (buff 32))
    (witness-reserved-value (buff 32))
    (ctx (buff 4096))
    (cproof (list 14 (buff 32)))
  )
  (let (
      ;; Your existing BTC verification logic here...
      ;; (verifying the transaction was mined, etc.)
      
      ;; NEW: Try to parse Runes from the transaction
      (runes-result (parse-runes-from-transaction wtx))
      (has-runes (is-ok runes-result))
    )
    (if has-runes
      ;; Path 1: Transaction contains Runes
      (let (
          (runes-data (unwrap-panic runes-result))
          (rune-block (get block runes-data))
          (rune-tx (get tx-index runes-data))
          (rune-amount (get amount runes-data))
        )
        ;; Validate the rune is accepted
        (asserts! (is-accepted-rune rune-block rune-tx) ERR-UNSUPPORTED-RUNE)
        
        ;; Calculate swap using rune amount
        (let (
            (exchange-rate (get-rune-exchange-rate rune-block rune-tx))
            (ai-tokens-out (* rune-amount exchange-rate))
          )
          ;; Execute swap with rune amount
          ;; (your existing swap logic, but using ai-tokens-out)
          (ok { 
            type: "runes-swap",
            rune-amount: rune-amount,
            ai-tokens: ai-tokens-out
          })
        )
      )
      ;; Path 2: No Runes, proceed with BTC-only swap (your existing logic)
      (let (
          ;; Your existing BTC amount extraction
          (btc-amount u100000)  ;; Placeholder
        )
        ;; Execute BTC swap (your existing logic)
        (ok {
          type: "btc-swap",
          btc-amount: btc-amount
        })
      )
    )
  )
)

;; ============================================================================
;; Helper: Parse Runes from Transaction
;; ============================================================================

;; Wrapper function that finds and parses the runestone
;; Returns rune details if found, error if not
(define-read-only (parse-runes-from-transaction
    (wtx {
      version: uint,
      segwit-marker: uint,
      segwit-version: uint,
      ins: (list 50 {
        outpoint: {
          hash: (buff 32),
          index: uint,
        },
        scriptSig: (buff 1376),
        sequence: uint,
      }),
      outs: (list 50 {
        value: uint,
        scriptPubKey: (buff 1376),
      }),
      txid: (optional (buff 32)),
      witnesses: (list 50 (list 13 (buff 1376))),
      locktime: uint,
    })
  )
  (let (
      ;; Find the OP_RETURN output with runestone
      (runestone-output (try! (find-runestone-in-outputs (get outs wtx))))
      (script (get scriptPubKey runestone-output))
    )
    ;; Parse the runestone
    ;; We expect it to transfer to output 1 (the pool)
    (parse-runestone-any-rune script u1)
  )
)

;; Find output containing a runestone
(define-private (find-runestone-in-outputs
    (outputs (list 50 {
      value: uint,
      scriptPubKey: (buff 1376)
    }))
  )
  (let (
      (result (fold check-output
        outputs
        { found: false, output: { value: u0, scriptPubKey: 0x } }
      ))
    )
    (if (get found result)
      (ok (get output result))
      ERR-NO-RUNES-FOUND
    )
  )
)

(define-private (check-output
    (output {
      value: uint,
      scriptPubKey: (buff 1376)
    })
    (state {
      found: bool,
      output: {
        value: uint,
        scriptPubKey: (buff 1376)
      }
    })
  )
  (if (get found state)
    state
    (if (is-runestone (get scriptPubKey output))
      { found: true, output: output }
      state
    )
  )
)

;; Check if script is a runestone
(define-private (is-runestone (script (buff 1376)))
  (and
    (is-eq (default-to 0x00 (element-at? script u0)) 0x6a)
    (is-eq (default-to 0x00 (element-at? script u1)) 0x5d)
  )
)

;; Parse runestone for any rune (doesn't validate which rune)
;; Returns the rune details
(define-private (parse-runestone-any-rune
    (script (buff 1376))
    (expected-output uint)
  )
  (let (
      ;; Parse tag
      (tag-result (try! (decode-leb128 script u2)))
    )
    ;; Must be edict tag (0)
    (asserts! (is-eq (get value tag-result) u0) ERR-NO-RUNES-FOUND)
    
    ;; Parse edict
    (let (
        (offset (get next-offset tag-result))
        ;; Decode block
        (block-result (try! (decode-leb128 script offset)))
        ;; Decode tx
        (tx-result (try! (decode-leb128 script (get next-offset block-result))))
        ;; Decode amount
        (amount-result (try! (decode-leb128 script (get next-offset tx-result))))
        ;; Decode output
        (output-result (try! (decode-leb128 script (get next-offset amount-result))))
      )
      ;; Verify output matches expected (pool)
      (asserts! (is-eq (get value output-result) expected-output) ERR-NO-RUNES-FOUND)
      
      (ok {
        block: (get value block-result),
        tx-index: (get value tx-result),
        amount: (get value amount-result),
        output: (get value output-result)
      })
    )
  )
)

;; ============================================================================
;; LEB128 Decoder (minimal inline version)
;; ============================================================================

(define-constant ERR-LEB128-FAILED (err u9999))

(define-read-only (decode-leb128 (data (buff 4096)) (start uint))
  (let (
      (result (fold decode-byte
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)
        {
          data: data,
          offset: start,
          value: u0,
          shift: u0,
          done: false,
          error: false
        }
      ))
    )
    (asserts! (not (get error result)) ERR-LEB128-FAILED)
    (ok {
      value: (get value result),
      next-offset: (get offset result)
    })
  )
)

(define-private (decode-byte (idx uint) (state {
    data: (buff 4096),
    offset: uint,
    value: uint,
    shift: uint,
    done: bool,
    error: bool
  }))
  (if (or (get done state) (get error state))
    state
    (match (element-at? (get data state) (get offset state))
      byte (let (
          (data-bits (bit-and byte 0x7f))
          (has-more (is-eq (bit-and byte 0x80) 0x80))
          (contribution (* data-bits (pow u2 (get shift state))))
        )
        {
          data: (get data state),
          offset: (+ (get offset state) u1),
          value: (+ (get value state) contribution),
          shift: (+ (get shift state) u7),
          done: (not has-more),
          error: false
        }
      )
      (merge state { error: true, done: true })
    )
  )
)

;; ============================================================================
;; Integration Points with Your Existing Contract
;; ============================================================================

;; STEP-BY-STEP INTEGRATION GUIDE:
;;
;; 1. ADD RUNES CONSTANTS
;;    - Copy the rune configuration constants to your contract
;;    - Set which runes you want to accept
;;    - Define exchange rates
;;
;; 2. ADD LEB128 DECODER
;;    - Copy the decode-leb128 function to your contract
;;    - Or import from separate contract
;;
;; 3. ADD RUNES PARSING
;;    - Copy parse-runes-from-transaction and helpers
;;    - Integrate into your existing swap function
;;
;; 4. MODIFY SWAP LOGIC
;;    In your existing swap-btc-to-aibtc function:
;;    
;;    a) After verifying BTC transaction is mined
;;    b) Try to parse runes: (parse-runes-from-transaction wtx)
;;    c) If runes found:
;;       - Validate accepted rune
;;       - Calculate AI tokens from rune amount
;;       - Execute swap
;;    d) If no runes:
;;       - Continue with BTC-only logic (existing)
;;
;; 5. UPDATE PAYLOAD PARSING
;;    Your existing payload already has the Stacks address.
;;    You can use the same mechanism - no changes needed!
;;    The runestone just adds rune transfer info.
;;
;; 6. TESTING
;;    - Test with BTC-only transactions (existing flow)
;;    - Test with DOG rune transactions (new flow)
;;    - Test with unsupported runes (should fail)

;; ============================================================================
;; Example Transaction Flow
;; ============================================================================

;; User wants to swap 100 DOG runes for AI tokens:
;;
;; 1. User creates Bitcoin transaction:
;;    Input:  Their UTXO with 100 DOG + 0.001 BTC
;;    Output 0: OP_RETURN with:
;;              - Your existing payload (Stacks address, min-amount, dex-id)
;;              - Runestone (transfer 100 DOG to output 1)
;;    Output 1: Your pool address (receives DOG + BTC)
;;    Output 2: Change back to user
;;
;; 2. Transaction gets mined on Bitcoin
;;
;; 3. Relayer calls swap-btc-with-runes-to-aibtc:
;;    - Verifies BTC transaction mined ✓
;;    - Parses existing payload ✓
;;    - NEW: Parses runestone, finds 100 DOG ✓
;;    - NEW: Validates DOG is accepted ✓
;;    - NEW: Calculates 100 DOG × 1000 = 100,000 AI tokens ✓
;;    - Executes swap: sends 100k AI tokens to user ✓
;;
;; 4. User receives AI tokens on Stacks!

;; ============================================================================
;; Encoding the OP_RETURN (For User/Frontend)
;; ============================================================================

;; The OP_RETURN output needs to contain BOTH:
;; 1. Your existing payload (Stacks address + params)
;; 2. The runestone (Runes transfer)
;;
;; Structure:
;; OP_RETURN [length] [your-payload] [OP_13] [runestone-data]
;;
;; Example hex:
;; 6a                   // OP_RETURN
;; 4c                   // OP_PUSHDATA1 (next byte is length)
;; 50                   // 80 bytes follow
;; [your 32-byte payload with Stacks address, min-amount, dex-id]
;; 5d                   // OP_13 (Runes magic)
;; [runestone LEB128 data: tag + block + tx + amount + output]
;;
;; This way both parsers work:
;; - parse-payload-segwit finds your data at offset 2
;; - parse-runes finds runestone after your data

;; Pro tip: You might want to restructure slightly:
;; OP_RETURN OP_13 [runestone] [separator] [your-payload]
;; This keeps the Runes protocol cleaner

;; ============================================================================
;; Quick Start Checklist
;; ============================================================================

;; □ 1. Copy LEB128 decoder to your contract
;; □ 2. Copy Runes parsing functions
;; □ 3. Add DOG rune constants
;; □ 4. Modify swap function to check for runes
;; □ 5. Test with Testnet transactions
;; □ 6. Document for users how to format transactions
;; □ 7. Update frontend to support Runes
;; □ 8. Monitor first mainnet Runes swaps
;; □ 9. Add support for more runes as needed
