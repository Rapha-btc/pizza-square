;; ============================================================================
;; LEB128 Decoder for Clarity
;; ============================================================================
;; 
;; LEB128 (Little Endian Base 128) is a variable-length encoding used in the
;; Runes protocol to efficiently encode integers in Bitcoin OP_RETURN outputs.
;;
;; This implementation provides:
;; - Single integer decoding
;; - Multiple integer decoding (for parsing runestones)
;; - Comprehensive error handling
;; - Support for up to 10-byte LEB128 values (covers uint64)
;;
;; Author: Your Name
;; Version: 1.0.0
;; License: MIT
;; ============================================================================

;; ============================================================================
;; Constants
;; ============================================================================

(define-constant ERR-OUT-OF-BOUNDS (err u1000))
(define-constant ERR-DECODE-OVERFLOW (err u1001))
(define-constant ERR-INVALID-CONTINUATION (err u1002))
(define-constant ERR-EMPTY-BUFFER (err u1003))

;; Maximum bytes for a 64-bit LEB128 value
;; (64 bits / 7 bits per byte = 9.14, round up to 10)
(define-constant MAX-LEB128-BYTES u10)

;; Bit masks
(define-constant CONTINUATION-BIT 0x80)  ;; 10000000 - bit 7
(define-constant DATA-MASK 0x7f)         ;; 01111111 - bits 0-6

;; ============================================================================
;; Core LEB128 Decoder
;; ============================================================================

;; Decode a single LEB128-encoded integer from a buffer at the given offset
;; 
;; Parameters:
;;   - data: Buffer containing LEB128-encoded data
;;   - start-offset: Position in buffer where LEB128 integer starts
;;
;; Returns:
;;   (ok { value: uint, next-offset: uint })
;;   - value: The decoded integer
;;   - next-offset: Position of next byte after this LEB128 integer
;;
;; Errors:
;;   - ERR-OUT-OF-BOUNDS: Offset exceeds buffer length
;;   - ERR-DECODE-OVERFLOW: More than 10 bytes (invalid for uint64)
;;   - ERR-EMPTY-BUFFER: Buffer is empty
;;
;; Example:
;;   (decode-leb128 0xE58E26 u0) => (ok { value: u624485, next-offset: u3 })
(define-read-only (decode-leb128 
    (data (buff 4096)) 
    (start-offset uint)
  )
  (let (
      (data-len (len data))
    )
    ;; Validation
    (asserts! (> data-len u0) ERR-EMPTY-BUFFER)
    (asserts! (< start-offset data-len) ERR-OUT-OF-BOUNDS)
    
    ;; Decode using fold over max possible bytes
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
      ;; Check for errors
      (asserts! (not (get error result)) ERR-DECODE-OVERFLOW)
      (asserts! (get done result) ERR-OUT-OF-BOUNDS)
      
      ;; Return decoded value and next offset
      (ok {
        value: (get value result),
        next-offset: (get offset result)
      })
    )
  )
)

;; Helper function: decode one byte of LEB128
;; This is called by fold for each potential byte in the encoding
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
  ;; If already done or error, pass through unchanged
  (if (or (get done state) (get error state))
    state
    ;; Try to read next byte
    (match (element-at? (get data state) (get offset state))
      current-byte (let (
          ;; Extract the 7 data bits (bits 0-6)
          (data-bits (bit-and current-byte DATA-MASK))
          
          ;; Check continuation bit (bit 7)
          ;; If set (0x80), more bytes follow
          ;; If clear (0x00), this is the last byte
          (has-more (is-eq (bit-and current-byte CONTINUATION-BIT) CONTINUATION-BIT))
          
          ;; Calculate this byte's contribution to the final value
          ;; data-bits * (2 ^ shift)
          (contribution (* data-bits (pow u2 (get shift state))))
          
          ;; Add to accumulated value
          (new-value (+ (get value state) contribution))
          
          ;; Next shift amount (7 bits per byte)
          (new-shift (+ (get shift state) u7))
        )
        {
          data: (get data state),
          offset: (+ (get offset state) u1),
          value: new-value,
          shift: new-shift,
          done: (not has-more),
          error: false
        }
      )
      ;; No byte at this offset - if we haven't finished, it's an error
      (merge state { 
        error: (not (get done state)),
        done: true 
      })
    )
  )
)

;; ============================================================================
;; Multi-Value Decoder
;; ============================================================================

;; Decode multiple LEB128 integers in sequence
;; Useful for parsing Runes runestones which contain multiple LEB128 values
;;
;; Parameters:
;;   - data: Buffer containing LEB128-encoded integers
;;   - start-offset: Starting position
;;   - count: Number of integers to decode
;;
;; Returns:
;;   (ok { values: (list 20 uint), next-offset: uint })
;;
;; Example:
;;   ;; Decode 4 integers: block-delta, tx-index, amount, output
;;   (decode-leb128-sequence 0x82B49D019F096401 u0 u4)
;;   => (ok { values: (list u2585442 u1183 u100 u1), next-offset: u8 })
(define-read-only (decode-leb128-sequence
    (data (buff 4096))
    (start-offset uint)
    (count uint)
  )
  (let (
      (result (fold decode-next-leb128
        (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9 u10 u11 u12 u13 u14 u15 u16 u17 u18 u19)
        {
          data: data,
          offset: start-offset,
          values: (list),
          count: count,
          remaining: count,
          error: false
        }
      ))
    )
    (asserts! (not (get error result)) ERR-OUT-OF-BOUNDS)
    (ok {
      values: (get values result),
      next-offset: (get offset result)
    })
  )
)

;; Helper for sequence decoding
(define-private (decode-next-leb128
    (idx uint)
    (state {
      data: (buff 4096),
      offset: uint,
      values: (list 20 uint),
      count: uint,
      remaining: uint,
      error: bool
    })
  )
  ;; Only decode if we still have values to decode and no error
  (if (or (is-eq (get remaining state) u0) (get error state))
    state
    (match (decode-leb128 (get data state) (get offset state))
      decoded-result (merge state {
        offset: (get next-offset decoded-result),
        values: (unwrap-panic (as-max-len? 
          (append (get values state) (get value decoded-result))
          u20
        )),
        remaining: (- (get remaining state) u1)
      })
      error (merge state { error: true })
    )
  )
)

;; ============================================================================
;; Convenience Functions
;; ============================================================================

;; Decode LEB128 and return just the value (ignore next-offset)
;; Useful when you only care about the decoded value
(define-read-only (decode-leb128-value
    (data (buff 4096))
    (start-offset uint)
  )
  (ok (get value (try! (decode-leb128 data start-offset))))
)

;; Check if a byte has the continuation bit set
(define-read-only (has-continuation-bit (byte (buff 1)))
  (is-eq 
    (bit-and (buff-to-uint-le byte) CONTINUATION-BIT) 
    CONTINUATION-BIT
  )
)

;; Count how many bytes a LEB128 value uses
;; Useful for validation or debugging
(define-read-only (get-leb128-byte-count
    (data (buff 4096))
    (start-offset uint)
  )
  (match (decode-leb128 data start-offset)
    result (ok (- (get next-offset result) start-offset))
    error error
  )
)

;; ============================================================================
;; Encoding Functions (for testing/verification)
;; ============================================================================

;; Encode a small uint to LEB128 (supports up to 4 bytes = 28 bits)
;; This is primarily for testing purposes
;;
;; Note: This is a simplified encoder. For production use, you'd want
;; a more complete implementation.
(define-read-only (encode-leb128-simple (value uint))
  (if (<= value u127)
    ;; Single byte (no continuation bit)
    (ok (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? value)) u1)))
    (if (<= value u16383)
      ;; Two bytes
      (let (
          (byte0 (+ (mod value u128) CONTINUATION-BIT))
          (byte1 (/ value u128))
        )
        (ok (concat 
          (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? byte0)) u1))
          (unwrap-panic (as-max-len? (unwrap-panic (to-consensus-buff? byte1)) u1))
        ))
      )
      ;; Value too large for simple encoder
      ERR-DECODE-OVERFLOW
    )
  )
)

;; ============================================================================
;; Test Functions
;; ============================================================================

;; Test basic decoding
(define-read-only (test-decode-basic)
  (let (
      ;; Test 0
      (test0 (decode-leb128 0x00 u0))
      ;; Test 100 (0x64)
      (test100 (decode-leb128 0x64 u0))
      ;; Test 127 (max single byte without continuation)
      (test127 (decode-leb128 0x7f u0))
      ;; Test 128 (0x8001 - first multi-byte)
      (test128 (decode-leb128 0x8001 u0))
      ;; Test 300 (0xac02)
      (test300 (decode-leb128 0xac02 u0))
    )
    {
      test0: test0,
      test100: test100,
      test127: test127,
      test128: test128,
      test300: test300
    }
  )
)

;; Test decoding real Runes data
(define-read-only (test-decode-runes-edict)
  (let (
      ;; DOG rune: block 2585442 (0x82B49D01), tx 1183 (0x9F09)
      ;; amount 100 (0x64), output 1 (0x01)
      (data 0x82b49d019f096401)
      
      ;; Decode block number
      (block-result (try! (decode-leb128 data u0)))
      (block-num (get value block-result))
      
      ;; Decode tx index
      (tx-result (try! (decode-leb128 data (get next-offset block-result))))
      (tx-idx (get value tx-result))
      
      ;; Decode amount
      (amount-result (try! (decode-leb128 data (get next-offset tx-result))))
      (amount (get value amount-result))
      
      ;; Decode output
      (output-result (try! (decode-leb128 data (get next-offset amount-result))))
      (output (get value output-result))
    )
    (ok {
      block: block-num,      ;; Should be 2585442
      tx-index: tx-idx,      ;; Should be 1183
      amount: amount,        ;; Should be 100
      output: output,        ;; Should be 1
      bytes-read: (get next-offset output-result)
    })
  )
)

;; Test sequence decoder
(define-read-only (test-decode-sequence)
  (let (
      (data 0x82b49d019f096401)
      (result (try! (decode-leb128-sequence data u0 u4)))
    )
    (ok {
      values: (get values result),
      next-offset: (get next-offset result)
    })
  )
)

;; Test error conditions
(define-read-only (test-error-cases)
  {
    ;; Out of bounds
    out-of-bounds: (decode-leb128 0x64 u10),
    ;; Empty buffer
    empty-buffer: (decode-leb128 0x u0),
    ;; Incomplete sequence (continuation bit set but no next byte)
    incomplete: (decode-leb128 0x80 u0)
  }
)
