;; Author: Eriq Ferrari  
;; Name: eriq.btc  
;; Title: Deflationary Token
;; Version: 1.0
;; Website: www.stxmap.co
;; License: MIT

;; The basic contract is tailored to get some specific supply, feel free to change accordingly to your needs

;; Initial Token Supply 100M
;; Initial Burn Supply 31M locked in this contract
;; Circulating Supply 69M


;; Mainnet Fungible Token trait
(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Testnet Fungible Token trait
;; (impl-trait .sip-010-trait-ft-standard.sip-010-trait)

;; Define the Fungible Token Name
(define-fungible-token DEFLAT TOKEN_SUPPLY) ;; you can change the token name to your preferred name

;; Define errors
(define-constant ERR_OWNER_ONLY (err u100))
(define-constant ERR_NOT_TOKEN_OWNER (err u101))
(define-constant ERR_IS_ZERO (err u102))
(define-constant ERR_WRONG_ADDRESS (err u102))

;; Define constants and variables to initialize the contract
(define-data-var CONTRACT_OWNER principal tx-sender)
(define-data-var TOKEN_URI (optional (string-utf8 256)) (some u"https://gateway.pinata.cloud/ipfs/QmW1z9wzeNY8ERCouVaDJrimJRgcS6rzXVAFECV2gNehSG"))
(define-constant TOKEN_NAME "Deflatio")
(define-constant TOKEN_SYMBOL "DEFLAT")
(define-constant TOKEN_DECIMALS u6) ;; 6 units displayed past decimal, e.g. 1.000_000 = 1 token
(define-constant TOKEN_SUPPLY u100000000000000) ;; 100M Total Supply
(define-constant INITIAL_BURN_SUPPLY u31000000000000) ;; 31M Initial Burn Supply
(define-data-var BURNER_COUNTER uint u0) ;; counter to track amount to burn according to algo
(define-data-var TOTAL_BURNED uint u0) ;; total burned counter.

;; BURN PERCENTAGE PARAMETERS
;; all the values are in 1e12 scale (1 = u1000000000000)
(define-constant K_MAX u2100000000000) ;; k_max = 2.1% max deflat percentage || you can edit this amount 
(define-constant K_MIN u10000000000) ;; k_min = 0.01% min deflat percentage || you can edit this amount
;; Alpha constant define the speed of the deflaction decrease
(define-constant ALPHA u690000000000) ;; 1% is linear / 0.75% fast / 0.5% medium / 0.25% slow / 0 slowest fixed at 10%of K_MIN

;; SINGLE ADDRESS COUNTER
(define-map DEFLATERS principal uint)
(define-map BURNERS principal uint)

;; SIP-010 function: Get the token balance of a specified principal
(define-read-only (get-balance (who principal))
  (ok (ft-get-balance DEFLAT who))
)

;; SIP-010 function: Returns the total supply of fungible token
(define-read-only (get-total-supply)
  (ok (ft-get-supply DEFLAT))
)

;; SIP-010 function: Returns the human-readable token name
(define-read-only (get-name)
  (ok TOKEN_NAME)
)

;; SIP-010 function: Returns the symbol or "ticker" for this token
(define-read-only (get-symbol)
  (ok TOKEN_SYMBOL)
)

;; SIP-010 function: Returns number of decimals to display
(define-read-only (get-decimals)
  (ok TOKEN_DECIMALS)
)
 
;; SIP-010 function: define token URI
(define-public (set-token-uri (value (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender (var-get CONTRACT_OWNER)) ERR_OWNER_ONLY)
        (var-set TOKEN_URI (some value))
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

;; SIP-010 function: renounce the ownership setting the contract as the owner
(define-public (renounce-ownership)
    (begin
        (asserts! (is-eq tx-sender (var-get CONTRACT_OWNER)) ERR_OWNER_ONLY)
        (var-set CONTRACT_OWNER (as-contract tx-sender))
        (ok (print {
              notification: "ownership-renounced",
              payload: {
                contract-id: (as-contract tx-sender),
                token-class: "ft"
              }
            })
        )
    )
)

;; SIP-010 function: Returns the URI containing token metadata
(define-read-only (get-token-uri)
    (ok (var-get TOKEN_URI)
    )
)

;; SIP-010 helper: Returns the contract balance
(define-read-only (get-contract-balance)
  (unwrap-panic (as-contract (get-balance tx-sender)))
)

;; SIP-010 function: Transfers tokens to a recipient
;; Sender must be the same as the caller to prevent principals from transferring tokens they do not own.
;; the Deflactionary mechanism runs parallely with every token transfer, but, due to post conditions of
;; the Stacks blockchain, the amount to be burned is recorded in the smart contract.
;; Every user will increment his personal contribute to the mechanism, increasing the Burning Power in the deflat function

(define-public (transfer
  (amount uint)
  (sender principal)
  (recipient principal)
  (memo (optional (buff 34)))
)
  (let (
        (BURN_PERCENTAGE (CALCULATE_BURN_PERCENTAGE) )
        (BURN_AMOUNT (/ (* amount BURN_PERCENTAGE) u1000000000000))
        (senderDeflated (get-deflated sender))
        (new-amount (+ senderDeflated BURN_AMOUNT))
        (new-counter (+ (var-get BURNER_COUNTER) BURN_AMOUNT ))
  )
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (> amount u0) ERR_IS_ZERO)
    (asserts! (is-standard recipient) ERR_WRONG_ADDRESS)
    (map-set DEFLATERS sender new-amount)
    (var-set BURNER_COUNTER new-counter)
    (try! (ft-transfer? DEFLAT amount sender recipient))
    (print {a: "transfer", counter: new-counter, amount: new-amount})
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; public function to contribute to the deflactionary mechanism
;; every user can burn up to the max of the available tokens in the contract
;; but every user has a personal limit per transaction equal to the total
;; amount as Deflater, called as the Burning Power (sum of all burn amounts of every user transfer)

(define-public (deflat)
(let (
     (amount (unwrap-panic (deflat-amout tx-sender)))
     (burned (get-burned tx-sender))
     (new-burned (+ burned amount))
     (new-amount (+ (var-get TOTAL_BURNED) amount))
) 
  (asserts! (> amount u0) ERR_IS_ZERO)
  (var-set TOTAL_BURNED new-amount)
  (map-set BURNERS tx-sender new-burned)
  (print { a: "deflat", amount: amount, totalBurned: new-amount, userBurned: new-burned })
  (as-contract (ft-burn? DEFLAT amount tx-sender ))
) 
)

;; public function to contribute to the deflactionary mechanism
;; every user can send extra tokens to extend the duration of the deflation
;; the amount will be added to user counter of burned tokens

(define-public (send-to-burner (amount uint) (sender principal))
(let (
    (burned (get-burned sender))
    (new-amount (+ burned amount))
) 
  (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
  (asserts! (> amount u0) ERR_IS_ZERO)
  (map-set BURNERS sender new-amount)
  (print { a: "sendToBurner", amount: amount, userBurned: new-amount })
  (ft-transfer? DEFLAT amount tx-sender (as-contract tx-sender))
) 
)

;; SIP-010 function: Burn tokens
;; Sender must be the same as the caller to prevent principals from burning tokens they do not own.
;; Every token burned by the user will be added to his personal counter of burned tokens

(define-public (burn (amount uint) (sender principal) )
  (let (
    (burned (get-burned sender))
    (new-burned (+ burned amount))
    (new-amount (+ (var-get TOTAL_BURNED) amount))
  )
    (asserts! (is-eq tx-sender sender) ERR_NOT_TOKEN_OWNER)
    (asserts! (> amount u0) ERR_IS_ZERO)
    (print { a: "burn", amount: amount, totalBurned: new-amount, userBurned: new-burned  })
    (var-set TOTAL_BURNED new-amount)
    (map-set BURNERS sender new-burned)
    (ft-burn? DEFLAT amount sender))
)

;; send-many tokens: good for airdrop and multiple transfers

(define-public (send-many (recipients (list 500 { to: principal, amount: uint, memo: (optional (buff 34)) })))
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

;; return the total contribute of the user to the deflat mechanism
;; it's the sum of all the burn amount from all the user transfers

(define-read-only (get-deflated (address principal))
  (default-to u0 (map-get? DEFLATERS address))
)

;; return the total amount of tokens burned by a user

(define-read-only (get-burned (address principal))
  (default-to u0 (map-get? BURNERS address))
)

;; calculate the amount of tokens available to deflat
;; it's the difference between the deflat counter and the total burned amount

(define-read-only (available-to-burn )
  (- (var-get BURNER_COUNTER) (var-get TOTAL_BURNED))
)

;; calculate the amount that can be burned by the user with the public deflat function

(define-read-only (deflat-amout (address principal))
  (let (
    (to-burn (available-to-burn))
    (deflated (get-deflated address))
  )
  (if (>= deflated to-burn)
  (ok to-burn)
  (ok deflated)
  )
  )
)

;; Calculate burn percentage
;; This function calculates the percentage of tokens to burn during a transaction.
;; It applies a deflationary model where the burn rate decreases as the total supply decreases.
;; The calculation involves the following steps:
;; 1. Retrieve the current total supply of tokens (C).
;; 2. Calculate the ratio of the current supply (C) to the initial supply (I) with a scaling factor of 1e12.
;; 3. Apply the ALPHA factor to adjust the deflation speed and scale the result back down.
;; 4. Compute the adjustment to the burn percentage by applying the difference between K_MAX and K_MIN to the adjusted ratio.
;; 5. Add the minimum burn rate (K_MIN) to the adjustment to get the final burn percentage.
;; 6. The result is divided by 100 to express the burn percentage as a fraction of the amount transferred.

(define-read-only (CALCULATE_BURN_PERCENTAGE)
  (let (
        (C (unwrap-panic (get-total-supply)))
        (C_DIV_I (/ (* C u1000000000000) TOKEN_SUPPLY)) ;; Calculate C/I with scale 1e12
        (C_DIV_I_ADJ (/ (* C_DIV_I ALPHA) u1000000000000)) ;; Apply ALPHA and scale down
        (ADJUSTMENT (/ (* (- K_MAX K_MIN) C_DIV_I_ADJ) u1000000000000)) ;; Calculate (K_MAX - K_MIN) * C_DIV_I_ADJ and scale down
       )
    (/ (+ K_MIN ADJUSTMENT) u100) ;; Final burn percentage
  )
)

;; Mint Total Supply. It will be not possible to mint new tokens

(begin
  (try! (ft-mint? DEFLAT TOKEN_SUPPLY tx-sender))
)

;; Transfer the initial burn reserve to the smart contract
;; it will be possible only to burn this tokens, no functions to withdraw!

(transfer INITIAL_BURN_SUPPLY tx-sender (as-contract tx-sender) none)

