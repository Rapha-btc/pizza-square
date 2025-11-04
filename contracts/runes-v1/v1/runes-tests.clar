;; ============================================================================
;; Test Suite for LEB128 Decoder and Runes Parser
;; ============================================================================
;;
;; This file contains comprehensive tests for the LEB128 decoder and Runes
;; parser implementations. Run these to verify correct functionality.
;;
;; Test categories:
;; 1. LEB128 basic encoding/decoding
;; 2. LEB128 edge cases and errors
;; 3. Runes protocol parsing
;; 4. Integration with Bitcoin transactions
;; 5. Real-world examples
;;
;; ============================================================================

;; Import the contracts (adjust paths as needed)
;; (use-trait leb128-decoder .leb128-decoder)
;; (use-trait runes-parser .runes-parser)

;; ============================================================================
;; Test Data: Real Runes Examples
;; ============================================================================

;; DOG•GO•TO•THE•MOON rune
;; One of the most popular runes
(define-constant DOG-RUNE-BLOCK u2585442)
(define-constant DOG-RUNE-TX u1183)
(define-constant DOG-RUNE-NAME "DOG•GO•TO•THE•MOON")

;; RSIC rune (another popular one)
(define-constant RSIC-RUNE-BLOCK u2510010)
(define-constant RSIC-RUNE-TX u617)

;; ============================================================================
;; LEB128 Test Cases
;; ============================================================================

;; Test Case 1: Single-byte values (0-127)
;; These fit in one byte without continuation bit
(define-read-only (test-leb128-single-byte)
  {
    zero: {
      input: 0x00,
      expected: u0,
      description: "Zero value"
    },
    one: {
      input: 0x01,
      expected: u1,
      description: "Value 1"
    },
    hundred: {
      input: 0x64,
      expected: u100,
      description: "Value 100"
    },
    max-single: {
      input: 0x7f,
      expected: u127,
      description: "Max single-byte (127)"
    }
  }
)

;; Test Case 2: Two-byte values (128-16383)
;; Require continuation bit
(define-read-only (test-leb128-two-bytes)
  {
    min-two-byte: {
      input: 0x8001,
      expected: u128,
      description: "128 = 0b10000000 0b00000001"
    },
    two-fifty-seven: {
      input: 0x8102,
      expected: u257,
      description: "257 = 0b10000001 0b00000010"
    },
    dog-tx-index: {
      input: 0x9f09,
      expected: u1183,
      description: "DOG tx index = 0b10011111 0b00001001"
    },
    sixteen-k: {
      input: 0x808001,
      expected: u16384,
      description: "16384 requires 3 bytes"
    }
  }
)

;; Test Case 3: Multi-byte values
;; Large numbers used in block heights
(define-read-only (test-leb128-multi-byte)
  {
    dog-block: {
      input: 0x82b49d01,
      expected: u2585442,
      description: "DOG block height"
    },
    rsic-block: {
      input: 0xeae49801,
      expected: u2510010,
      description: "RSIC block height"
    },
    large-value: {
      input: 0xe58e26,
      expected: u624485,
      description: "Three-byte encoding"
    }
  }
)

;; Test Case 4: Error conditions
(define-read-only (test-leb128-errors)
  {
    out-of-bounds: {
      input: 0x64,
      offset: u10,
      expected-error: true,
      description: "Offset beyond buffer"
    },
    empty-buffer: {
      input: 0x,
      offset: u0,
      expected-error: true,
      description: "Empty buffer"
    },
    incomplete-sequence: {
      input: 0x80,
      offset: u0,
      expected-error: true,
      description: "Continuation bit set but no next byte"
    }
  }
)

;; ============================================================================
;; Runes Protocol Test Cases
;; ============================================================================

;; Test Case 5: Valid runestone structures
(define-read-only (test-valid-runestones)
  {
    simple-transfer: {
      ;; OP_RETURN + OP_13 + tag(0) + block + tx + amount + output
      script: 0x6a5d0082b49d019f096401,
      expected-block: u2585442,
      expected-tx: u1183,
      expected-amount: u100,
      expected-output: u1,
      description: "Transfer 100 DOG to output 1"
    },
    large-amount: {
      script: 0x6a5d0082b49d019f09a00f01,
      expected-block: u2585442,
      expected-tx: u1183,
      expected-amount: u1952,
      expected-output: u1,
      description: "Transfer 1952 DOG to output 1"
    },
    different-output: {
      script: 0x6a5d0082b49d019f096402,
      expected-block: u2585442,
      expected-tx: u1183,
      expected-amount: u100,
      expected-output: u2,
      description: "Transfer to output 2 instead"
    }
  }
)

;; Test Case 6: Invalid runestones
(define-read-only (test-invalid-runestones)
  {
    wrong-magic: {
      script: 0x6a5c0082b49d019f096401,
      description: "Wrong OP code (5c instead of 5d)",
      should-fail: true
    },
    no-op-return: {
      script: 0x5d0082b49d019f096401,
      description: "Missing OP_RETURN",
      should-fail: true
    },
    wrong-tag: {
      script: 0x6a5d0282b49d019f096401,
      description: "Non-zero tag (should be 0 for edicts)",
      should-fail: true
    },
    too-short: {
      script: 0x6a5d,
      description: "Script too short",
      should-fail: true
    }
  }
)

;; Test Case 7: Multiple edicts (advanced)
;; Note: Current simple parser only handles one edict
;; This shows what multi-edict runestones look like
(define-read-only (test-multi-edict-structure)
  {
    description: "Two edicts in one runestone",
    note: "First edict uses absolute block/tx, second uses deltas",
    structure: {
      ;; Edict 1: DOG (2585442:1183), 100 units, output 1
      ;; Edict 2: Same rune (delta 0:0), 50 units, output 2
      ;; Encoded: tag(0) + [block:tx:amt:out] + [block-delta:tx-delta:amt:out]
      script: 0x6a5d0082b49d019f0964010000320202,
      edict1: {
        block: u2585442,
        tx: u1183,
        amount: u100,
        output: u1
      },
      edict2: {
        block: u2585442,  ;; Same (delta = 0)
        tx: u1183,        ;; Same (delta = 0)
        amount: u50,
        output: u2
      }
    }
  }
)

;; ============================================================================
;; Integration Test: Full Bitcoin Transaction
;; ============================================================================

;; Test Case 8: Complete Bitcoin transaction with Runes
(define-read-only (test-bitcoin-transaction-integration)
  {
    description: "Simulated Bitcoin transaction sending DOG runes to a pool",
    transaction: {
      inputs: "User's UTXO containing 100 DOG + 0.001 BTC",
      output-0: {
        type: "OP_RETURN",
        value: u0,
        scriptPubKey: 0x6a5d0082b49d019f096401,
        description: "Runestone: transfer 100 DOG to output 1"
      },
      output-1: {
        type: "P2WPKH",
        value: u100000,
        address: "bc1q...(pool address)",
        description: "Pool receives BTC + 100 DOG runes"
      },
      output-2: {
        type: "P2WPKH",
        value: u50000,
        address: "bc1q...(change address)",
        description: "Change back to sender"
      }
    },
    validation: {
      step1: "Parse transaction outputs",
      step2: "Find OP_RETURN output (index 0)",
      step3: "Verify magic bytes (6a 5d)",
      step4: "Decode LEB128 sequence",
      step5: "Validate rune ID matches DOG",
      step6: "Validate output index is 1",
      step7: "Extract amount (100)",
      result: "Pool can credit user with 100 DOG runes"
    }
  }
)

;; ============================================================================
;; Real-World Example: Swap Integration
;; ============================================================================

;; This shows how to integrate Runes parsing into your existing swap contract
(define-read-only (example-swap-integration-flow)
  {
    scenario: "User wants to swap 100 DOG runes for AI tokens",
    steps: {
      step1: {
        action: "User sends BTC transaction",
        details: {
          input: "UTXO with 100 DOG + BTC",
          output0: "OP_RETURN with runestone",
          output1: "Pool BTC address (receives DOG + BTC)",
          payload: "Stacks address encoded in OP_RETURN (existing method)"
        }
      },
      step2: {
        action: "Relayer calls swap-btc-to-aibtc",
        btc-verification: "Verify BTC transaction mined (existing)",
        payload-decode: "Extract Stacks receiver address (existing)",
        new-runes-verification: {
          call: "parse-runes-from-wtx",
          validate-rune-id: "Check it's DOG (2585442:1183)",
          validate-output: "Check it went to output 1 (pool)",
          extract-amount: "Get rune amount (100)"
        }
      },
      step3: {
        action: "Execute swap",
        input: "100 DOG runes",
        output: "X AI tokens (based on exchange rate)",
        transfer: "Send AI tokens to user's Stacks address"
      }
    },
    code-example: "See integration-example.clar"
  }
)

;; ============================================================================
;; Performance Test Data
;; ============================================================================

(define-read-only (test-performance-scenarios)
  {
    small-values: {
      description: "Fast path: single-byte LEB128",
      examples: (list u0 u1 u50 u100 u127),
      bytes-per-value: u1,
      estimated-cost: "Minimal"
    },
    medium-values: {
      description: "Common case: 2-3 byte LEB128",
      examples: (list u128 u1000 u10000 u100000),
      bytes-per-value: u2,
      estimated-cost: "Low"
    },
    large-values: {
      description: "Block heights: 3-4 byte LEB128",
      examples: (list u2585442 u2510010),
      bytes-per-value: u3,
      estimated-cost: "Moderate"
    }
  }
)

;; ============================================================================
;; Known Runes for Testing
;; ============================================================================

(define-read-only (get-known-test-runes)
  {
    dog: {
      name: "DOG•GO•TO•THE•MOON",
      id: "2585442:1183",
      block: u2585442,
      tx: u1183,
      divisibility: u0,
      symbol: "🐕"
    },
    rsic: {
      name: "RSIC",
      id: "2510010:617",
      block: u2510010,
      tx: u617,
      divisibility: u0,
      symbol: "⧉"
    },
    uncommon-goods: {
      name: "UNCOMMON•GOODS",
      id: "2500000:1",
      block: u2500000,
      tx: u1,
      divisibility: u2,
      symbol: "⧉"
    }
  }
)

;; ============================================================================
;; Helper: Generate Test Runestone
;; ============================================================================

;; This helps you manually construct runestones for testing
(define-read-only (construct-test-runestone
    (rune-block uint)
    (rune-tx uint)
    (amount uint)
    (output uint)
  )
  {
    description: "Manual runestone construction guide",
    hex-format: "0x6a 0x5d 0x00 [block-leb128] [tx-leb128] [amount-leb128] [output-leb128]",
    your-values: {
      rune-block: rune-block,
      rune-tx: rune-tx,
      amount: amount,
      output: output
    },
    encoding-steps: {
      step1: "Convert each uint to LEB128",
      step2: "Concatenate as hex",
      step3: "Prepend 0x6a5d00",
      step4: "Use in parse-simple-transfer"
    },
    example: {
      input: {
        block: u2585442,
        tx: u1183,
        amount: u100,
        output: u1
      },
      leb128-encoding: {
        block: "0x82b49d01",
        tx: "0x9f09",
        amount: "0x64",
        output: "0x01"
      },
      final-script: "0x6a5d0082b49d019f096401"
    }
  }
)

;; ============================================================================
;; Test Execution Guide
;; ============================================================================

(define-read-only (run-all-tests)
  {
    leb128-tests: {
      single-byte: (test-leb128-single-byte),
      two-bytes: (test-leb128-two-bytes),
      multi-byte: (test-leb128-multi-byte),
      errors: (test-leb128-errors)
    },
    runes-tests: {
      valid: (test-valid-runestones),
      invalid: (test-invalid-runestones),
      multi-edict: (test-multi-edict-structure)
    },
    integration-tests: {
      bitcoin-tx: (test-bitcoin-transaction-integration),
      swap-flow: (example-swap-integration-flow)
    },
    performance: (test-performance-scenarios),
    known-runes: (get-known-test-runes)
  }
)
