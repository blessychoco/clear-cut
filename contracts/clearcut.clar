;; Royalty Distribution Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-percentage (err u101))
(define-constant err-no-recipients (err u102))
(define-constant err-invalid-recipient (err u103))
(define-constant err-transfer-failed (err u104))

;; Define data maps
(define-map royalty-recipients principal uint)
(define-map recipient-list uint principal)
(define-map total-distributed uint uint)

;; Define a variable to keep track of the number of recipients
(define-data-var num-recipients uint u0)

;; Public function to set royalty percentage for a recipient
(define-public (set-royalty-percentage (recipient principal) (percentage uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= percentage u100) err-invalid-percentage)
    (if (is-none (map-get? royalty-recipients recipient))
      (let ((new-index (var-get num-recipients)))
        (map-set recipient-list new-index recipient)
        (var-set num-recipients (+ new-index u1)))
      true)
    (ok (map-set royalty-recipients recipient percentage))))

;; Public function to distribute royalties to a single recipient
(define-public (distribute-to-recipient (recipient-index uint) (amount uint))
  (let ((num-recip (var-get num-recipients)))
    (if (>= recipient-index num-recip)
      (err err-invalid-recipient)
      (match (map-get? recipient-list recipient-index)
        recipient 
          (let ((percentage (default-to u0 (map-get? royalty-recipients recipient)))
                (payment (/ (* amount percentage) u100)))
            (if (> payment u0)
              (begin
                (map-set total-distributed block-height
                  (+ (default-to u0 (map-get? total-distributed block-height)) payment))
                (match (as-contract (stx-transfer? payment tx-sender recipient))
                  success (ok payment)
                  error (err err-transfer-failed)))
              (ok u0)))
        (err err-invalid-recipient)))))

;; Read-only function to get royalty percentage for a recipient
(define-read-only (get-royalty-percentage (recipient principal))
  (ok (default-to u0 (map-get? royalty-recipients recipient))))

;; Read-only function to get total distributed amount
(define-read-only (get-total-distributed)
  (ok (default-to u0 (map-get? total-distributed block-height))))

;; Read-only function to get the number of recipients
(define-read-only (get-num-recipients)
  (ok (var-get num-recipients)))

;; Read-only function to get a recipient by index
(define-read-only (get-recipient-by-index (index uint))
  (ok (map-get? recipient-list index)))