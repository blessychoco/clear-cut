;; Royalty Distribution Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-percentage (err u102))

;; Define data maps
(define-map royalty-recipients principal uint)
(define-map total-distributed uint uint)

;; Public function to set royalty percentage for a recipient
(define-public (set-royalty-percentage (recipient principal) (percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= percentage u100) err-invalid-percentage)
    (ok (map-set royalty-recipients recipient percentage))))

;; Public function to distribute royalties
(define-public (distribute-royalties (amount uint))
  (let ((total-percentage u0)
        (remaining amount))
    (map-set total-distributed block-height 
      (+ (default-to u0 (map-get? total-distributed block-height)) amount))
    (ok (fold distribute-to-recipient 
              (map-to-list royalty-recipients) 
              remaining))))

;; Private function to distribute to a single recipient
(define-private (distribute-to-recipient (recipient (tuple (key principal) (value uint))) (remaining uint))
  (let ((recipient-principal (get key recipient))
        (percentage (get value recipient))
        (payment (/ (* remaining percentage) u100)))
    (if (> payment u0)
      (begin
        (try! (as-contract (stx-transfer? payment tx-sender recipient-principal)))
        (- remaining payment))
      remaining)))

;; Read-only function to get royalty percentage for a recipient
(define-read-only (get-royalty-percentage (recipient principal))
  (ok (default-to u0 (map-get? royalty-recipients recipient))))

;; Read-only function to get total distributed amount
(define-read-only (get-total-distributed)
  (ok (default-to u0 (map-get? total-distributed block-height))))
