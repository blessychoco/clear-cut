;; Royalty Distribution Smart Contract with Recurring Distributions

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-percentage (err u101))
(define-constant err-no-recipients (err u102))
(define-constant err-invalid-recipient (err u103))
(define-constant err-transfer-failed (err u104))
(define-constant err-recipient-not-found (err u105))
(define-constant err-distribution-failed (err u106))
(define-constant err-too-soon (err u107))

;; Define data maps
(define-map royalty-recipients principal uint)
(define-map recipient-list uint principal)
(define-map recipient-indices principal uint)
(define-map total-distributed uint uint)

;; Define variables to keep track of the number of recipients and distribution timing
(define-data-var num-recipients uint u0)
(define-data-var distribution-interval uint u1440) ;; e.g., once every 1440 blocks (~1 day)
(define-data-var last-distribution-block uint u0)

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
    (fold shift-single-recipient 
          (list removed-index (- num-recip u1))
          true)))

;; Helper function to shift a single recipient
(define-private (shift-single-recipient (index uint) (last bool))
  (match (map-get? recipient-list (+ index u1))
    next-recipient (begin
      (map-set recipient-list index next-recipient)
      (map-set recipient-indices next-recipient index)
      last)
    last))

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

;; New function to distribute royalties to all recipients in a single transaction
(define-public (batch-distribute-royalties (total-amount uint))
  (let ((num-recip (var-get num-recipients)))
    (if (is-eq num-recip u0)
      (err err-no-recipients)
      (let ((result (fold distribute-to-recipient-fold 
                          (list u0 (- num-recip u1)) 
                          (tuple (amount total-amount) (total-distributed u0) (success true)))))
        (if (get success result)
          (begin
            (map-set total-distributed block-height (get total-distributed result))
            (ok (get total-distributed result)))
          (err err-distribution-failed))))))

;; Helper function to distribute to a single recipient within the fold
(define-private (distribute-to-recipient-fold (index uint) (state (tuple (amount uint) (total-distributed uint) (success bool))))
  (if (get success state)
    (match (distribute-to-recipient index (get amount state))
      distributed-amount (merge state { total-distributed: (+ (get total-distributed state) distributed-amount) })
      error (merge state { success: false }))
    state))

;; Automated recurring distribution function
(define-public (automated-distribute (total-amount uint))
  (let ((current-block block-height)
        (last-distribution (var-get last-distribution-block))
        (interval (var-get distribution-interval)))
    (if (>= (- current-block last-distribution) interval)
      (begin
        (var-set last-distribution-block current-block)
        (batch-distribute-royalties total-amount))
      (err err-too-soon))))

;; Public function to adjust the distribution interval
(define-public (set-distribution-interval (new-interval uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set distribution-interval new-interval)
    (ok new-interval)))

;; Read-only function to get the current distribution interval
(define-read-only (get-distribution-interval)
  (ok (var-get distribution-interval)))

;; Read-only function to get the last distribution block
(define-read-only (get-last-distribution-block)
  (ok (var-get last-distribution-block)))

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
