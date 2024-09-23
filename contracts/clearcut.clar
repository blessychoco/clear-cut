;; Royalty Distribution Smart Contract

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-percentage (err u101))
(define-constant err-no-recipients (err u102))
(define-constant err-invalid-recipient (err u103))
(define-constant err-transfer-failed (err u104))
(define-constant err-recipient-not-found (err u105))

;; Define data maps
(define-map royalty-recipients principal uint)
(define-map recipient-list uint principal)
(define-map recipient-indices principal uint)
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
        (map-set recipient-indices recipient new-index)
        (var-set num-recipients (+ new-index u1)))
      true)
    (ok (map-set royalty-recipients recipient percentage))))

;; Public function to remove a recipient
(define-public (remove-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? recipient-indices recipient)
      index (begin
        (map-delete royalty-recipients recipient)
        (map-delete recipient-indices recipient)
        (shift-recipients index)
        (var-set num-recipients (- (var-get num-recipients) u1))
        (ok true))
      (ok false))))

;; Private function to shift recipients after removal
(define-private (shift-recipients (removed-index uint))
  (let ((num-recip (var-get num-recipients)))
    (map shift-single-recipient 
         (unwrap-panic (slice? (map-to-list) removed-index (- num-recip u1))))))

;; Helper function to shift a single recipient
(define-private (shift-single-recipient (index uint))
  (match (map-get? recipient-list (+ index u1))
    next-recipient (begin
      (map-set recipient-list index next-recipient)
      (map-set recipient-indices next-recipient index)
      true)
    false))

;; Helper function to create a list of indices to shift
(define-private (map-to-list)
  (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9))

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
              (match (as-contract (stx-transfer? payment tx-sender recipient))
                success (begin
                  (map-set total-distributed block-height
                    (+ (default-to u0 (map-get? total-distributed block-height)) payment))
                  (ok payment))
                error (err err-transfer-failed))
              (ok u0)))
        (err err-recipient-not-found)))))

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