;; d1a3714daca45882feb83a31570d18b5a3eeeee73fee9c555c6a80a2b3250702
;; b Powered By Faktory.fun v1.0 

(impl-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)
(impl-trait 'SP29CK9990DQGE9RGTT1VEQTTYH8KY4E3JE5XP4EC.aibtcdev-dao-traits-v1.token)
(use-trait token-trait 'SP3XXMS38VTAWTVPE5682XSBFXPTH7XCPEBTX8AN2.faktory-trait-v1.sip-010-trait)
(use-trait dex-trait 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.faktory-dex-trait.dex-trait) 

(define-constant ERR-NOT-AUTHORIZED u401)
(define-constant ERR-NOT-OWNER u402) 
(define-constant ERR-WRONG-FT-OUT u403) 

(define-fungible-token PIZZA MAX)
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
       (and (var-get gated) (asserts! (is-approved-recipient recipient) ERR_ENFORCE_ROYALTIES))
       (match (ft-transfer? PIZZA amount sender recipient)
          response (begin
            (print memo)
            (ok response))
          error (err error)
        )
    )
)

(define-public (sell-transfer
    (dex <dex-trait>)
    (amount-in uint)
    (ft-out <token-trait>))
    (let ((sender tx-sender)
          (dex-contract (contract-of dex))
          (info (try! (contract-call? dex sell SELF amount-in))) ;; maybe this also spits out ft-out-contract
          (ubtc-out (get ubtc-out info))
          (ft-out-contract (get ft info))
          (royal-amt (/ (* ubtc-out ROYALTY) PRECISION)))
        (asserts! (is-eq tx-sender sender) (err ERR-NOT-AUTHORIZED))
        (asserts! (is-eq (contract-of ft-out) ft-out-contract) ERR-WRONG-FT-OUT)
        (try! (ft-transfer? PIZZA (- ubtc-out royal-amt) sender dex-contract))
    (print {
        type: "sell",
        sender: sender,
        token-in: SELF,
        amount-in: amount,
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
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (ok (map-set approved-recipients recipient true))
  )
)

(define-public (revoke-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (ok (map-set approved-recipients recipient false))
  )
)

(define-private (is-approved-recipient (recipient principal))
  (or
    (validate-not-a-contract recipient)
    (default-to false (map-get? approved-recipients recipient)) 
  )
)

(define-public (set-gated (enabled bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
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
    (begin
      (asserts! (is-none (get name recipient-parts)) ERR_INVALID_OWNER_TYPE)
      (ok true)
    )
  )
)