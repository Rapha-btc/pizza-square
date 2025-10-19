;; d1a3714daca45882feb83a31570d18b5a3eeeee73fee9c555c6a80a2b3250702
;; b Powered By Faktory.fun v1.0 

(impl-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)
(impl-trait 'SP29CK9990DQGE9RGTT1VEQTTYH8KY4E3JE5XP4EC.aibtcdev-dao-traits-v1.token)
(use-trait token-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)
(use-trait dex-trait .faktory-dex-pizza-trait.dex-trait) 

(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-NOT-OWNER u402) 
(define-constant ERR-WRONG-FT-OUT u403) 
(define-constant ERR_INVALID_OWNER_TYPE u404) 
(define-constant ERR_ENFORCE_ROYALTIES u405) 
(define-constant ERR-SLIPPAGE u406) 

(define-fungible-token PIZZA MAX)

(define-constant SELF (as-contract tx-sender))
(define-constant MAX u100000000000000000)
(define-constant ROYALTY u1000)u10000
(define-constant PRECISION u10000)

(define-data-var contract-owner principal 'SP3TBQDEB5VRC42H5C97N4XYJVPH4CK3N9D00V4S1)
(define-data-var token-uri (optional (string-utf8 256)) (some u"https://www.ninjastrategy.fun/"))
(define-data-var gated bool true)

;; SIP-10 Functions
(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
       (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
       (and (var-get gated) (asserts! (is-approved-recipient recipient) (err ERR_ENFORCE_ROYALTIES)))
       (match (ft-transfer? PIZZA amount sender recipient)
          response (begin
            (print memo)
            (ok response))
          error (err error)
        )
    )
)

;; we need a new dex-trait with new signature here
(define-public (sell
    (amount-in uint)
    (ft-in <token-trait>)
    (sender principal)
    (recipient <dex-trait>) 
    (min-amount-out (optional uint))
    (ft-out <token-trait>))
    (let ((dex-contract (contract-of recipient))
          (info (try! (contract-call? recipient sell ft-in amount-in))) 
          (ubtc-out (get ubtc-out info))
          (ft-contract-out (get ft info))
          (min-out (default-to u0 min-amount-out))
          (royal-amt (/ (* ubtc-out ROYALTY) PRECISION)))
        ;; here we maintain an allow list of dexes / pools 
        ;; any dex / pool can allow itself if they pass contract-hash? verification
        (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-eq (contract-of ft-in) SELF) (err ERR-WRONG-FT-OUT))
        (asserts! (is-eq (contract-of ft-out) ft-contract-out) (err ERR-WRONG-FT-OUT))
        (asserts! (>= ubtc-out min-out) (err ERR-SLIPPAGE))
        (try! (ft-transfer? PIZZA amount-in sender dex-contract))
        (try! (contract-call? ft-out transfer royal-amt sender (var-get contract-owner) none))
    (print {
        type: "sell",
        sender: sender,
        token-in: SELF,
        amount-in: amount-in,
        token-out: ft-out,
        amount-out: ubtc-out,
        royalty: royal-amt,
        dex-contract: dex-contract })
    (ok ubtc-out))
)

(define-public (set-token-uri (value (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
        (var-set token-uri (some value))
        (ok (print {
              notification: "token-metadata-update",
              payload: {
                contract-id: (as-contract tx-sender),
                token-class: "ft"
              }
            })
        )
    )
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance PIZZA account))
)

(define-read-only (get-name)
  (ok "$PIZZA")
)

(define-read-only (get-symbol)
  (ok "PIZZA")
)

(define-read-only (get-decimals)
  (ok u8)
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply PIZZA))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (print {new-owner: new-owner})
    (ok (var-set contract-owner new-owner))
  )
)

;; ---------------------------------------------------------

(define-public (send-many (recipients (list 200 { to: principal, amount: uint, memo: (optional (buff 34)) })))
  (fold check-err (map send-token recipients) (ok true))
)

(define-private (check-err (result (response bool uint)) (prior (response bool uint)))
  (match prior ok-value result err-value (err err-value))
)

(define-private (send-token (recipient { to: principal, amount: uint, memo: (optional (buff 34)) }))
  (send-token-with-memo (get amount recipient) (get to recipient) (get memo recipient))
)

(define-private (send-token-with-memo (amount uint) (to principal) (memo (optional (buff 34))))
  (let ((transferOk (try! (transfer amount tx-sender to memo))))
    (ok transferOk)
  )
)

;; ---------------------------------------------------------

(begin 
    ;; ft distribution
    (try! (ft-mint? PIZZA (/ (* MAX u80) u100) 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-dex))
    (try! (ft-mint? PIZZA (/ (* MAX u20) u100) 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-pre-faktory))

    (print { 
        type: "faktory-trait-v1", 
        name: "$PIZZA",
        symbol: "PIZZA",
        token-uri: u"https://www.ninjastrategy.fun/", 
        tokenContract: (as-contract tx-sender),
        supply: MAX, 
        decimals: u8, 
    })
)

;; In contract enforced royalty
(define-map approved-recipients principal bool)

(define-public (approve-recipient (recipient principal))
;; in map or not a contract using destruct
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set approved-recipients recipient true))
  )
)

(define-public (revoke-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (map-set approved-recipients recipient false))
  )
)

(define-private (is-approved-recipient (recipient principal))
  (or
    (is-ok (validate-not-a-contract recipient))
    (default-to false (map-get? approved-recipients recipient)) 
  )
)

(define-public (set-gated (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err ERR-NOT-AUTHORIZED))
    (ok (var-set gated enabled))
  )
)

(define-read-only (is-gated)
  (var-get gated)
)

(define-private (validate-not-a-contract (recipient principal))
  (let (
    (recipient-parts (unwrap-panic (principal-destruct? recipient)))
  )
    (if (is-none (get name recipient-parts))
      (ok true)  ;; Not a contract, return (ok true)
      (err ERR_INVALID_OWNER_TYPE)  ;; Is a contract, return an error
    )
  )
)