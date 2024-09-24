;; Royalty Distribution Smart Contract with Simplified "Remove" Functionality

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

;; Define data maps to store recipients, indices, and distributed amounts
(define-map royalty-recipients principal uint) ;; Stores recipient percentages
(define-map recipient-list uint principal)     ;; Maps index to recipient
(define-map recipient-indices principal uint)  ;; Maps recipient to index
(define-map total-distributed uint uint)       ;; Tracks total distributed per block

;; Variables to track the number of recipients and distribution timing
(define-data-var num-recipients uint u0)              ;; Total recipients count
(define-data-var distribution-interval uint u1440)    ;; Time interval for recurring distribution (e.g., 1440 blocks ~ 1 day)
(define-data-var last-distribution-block uint u0)      ;; Last block where distribution occurred

;; Public function to set royalty percentage for a recipient.
;; This also adds a new recipient if they do not exist, or updates their percentage.
(define-public (set-royalty-percentage (recipient principal) (percentage uint))
  (begin
    ;; Ensure only the contract owner can set the percentage
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Ensure the percentage is between 0 and 100
    (asserts! (<= percentage u100) err-invalid-percentage)
    ;; If the recipient does not exist, add them to the recipient list
    (if (is-none (map-get? royalty-recipients recipient))
      (let ((new-index (var-get num-recipients)))
        (map-set recipient-list new-index recipient)
        (map-set recipient-indices recipient new-index)
        (var-set num-recipients (+ new-index u1)))
      true)
    ;; Set or update the recipient's percentage
    (ok (map-set royalty-recipients recipient percentage))))

;; Public function to distribute royalties to a single recipient.
;; This checks if the recipient is valid and skips those with 0% royalty.
;; Public function to distribute royalties to a single recipient with input validation
(define-public (distribute-to-recipient (recipient-index uint) (amount uint))
  (let ((num-recip (var-get num-recipients)))
    ;; Ensure the recipient index is valid
    (if (>= recipient-index num-recip)
      (err err-invalid-recipient)
      ;; Validate the amount is positive
      (if (<= amount u0)
        (err err-invalid-percentage) ;; Using this error for invalid amounts as well
        ;; Proceed with distribution if the index and amount are valid
        (match (map-get? recipient-list recipient-index)
          recipient 
            (let ((percentage (default-to u0 (map-get? royalty-recipients recipient)))
                  (payment (/ (* amount percentage) u100)))
              ;; Skip the recipient if their percentage is 0
              (if (> percentage u0)
                ;; Ensure payment is valid before transfer
                (if (> payment u0)
                  (match (as-contract (stx-transfer? payment tx-sender recipient))
                    success (begin
                      ;; Record the total amount distributed in the current block
                      (map-set total-distributed block-height
                        (+ (default-to u0 (map-get? total-distributed block-height)) payment))
                      (ok payment))
                    error (err err-transfer-failed))
                  ;; Handle case where payment is 0
                  (err err-invalid-percentage))
                ;; If the percentage is 0, no payment is made
                (ok u0)))
          ;; Handle case where recipient is not found
          (err err-recipient-not-found))))))

      

;; Public function to distribute royalties to all recipients in a single transaction.
;; It skips over recipients with 0% royalty.
(define-public (batch-distribute-royalties (total-amount uint))
  (let ((num-recip (var-get num-recipients)))
    ;; Check if there are any recipients
    (if (is-eq num-recip u0)
      (err err-no-recipients)
      ;; Distribute to all recipients via a fold operation
      (let ((result (fold distribute-to-recipient-fold 
                          (list u0 (- num-recip u1)) 
                          (tuple (amount total-amount) (total-distributed u0) (success true)))))
        ;; If the distribution is successful, record the total distributed
        (if (get success result)
          (begin
            (map-set total-distributed block-height (get total-distributed result))
            (ok (get total-distributed result)))
          (err err-distribution-failed))))))

;; Helper function for batch distribution (used in the fold).
;; It ensures the recipient's royalty is distributed only if their percentage is > 0.
(define-private (distribute-to-recipient-fold (index uint) (state (tuple (amount uint) (total-distributed uint) (success bool))))
  (if (get success state)
    ;; Distribute to the recipient at the current index
    (match (distribute-to-recipient index (get amount state))
      distributed-amount (merge state { total-distributed: (+ (get total-distributed state) distributed-amount) })
      error (merge state { success: false }))
    state))

;; Public function to trigger automated recurring distributions.
;; This checks if enough time (block intervals) has passed since the last distribution.
(define-public (automated-distribute (total-amount uint))
  (let ((current-block block-height)
        (last-distribution (var-get last-distribution-block))
        (interval (var-get distribution-interval)))
    ;; Check if the required number of blocks has passed for the next distribution
    (if (>= (- current-block last-distribution) interval)
      (begin
        ;; Update the last distribution block and trigger batch distribution
        (var-set last-distribution-block current-block)
        (batch-distribute-royalties total-amount))
      (err err-too-soon))))

;; Public function to set the distribution interval (in blocks).
;; This allows the contract owner to adjust how frequently distributions occur.
(define-public (set-distribution-interval (new-interval uint))
  (begin
    ;; Only the contract owner can set the interval
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Ensure the interval is greater than 0
    (asserts! (> new-interval u0) (err u108)) ;; Define a new error for invalid intervals
    ;; Set the new interval
    (var-set distribution-interval new-interval)
    (ok new-interval)))

;; Read-only function to get the current distribution interval.
(define-read-only (get-distribution-interval)
  (ok (var-get distribution-interval)))

;; Read-only function to get the last distribution block.
(define-read-only (get-last-distribution-block)
  (ok (var-get last-distribution-block)))

;; Read-only function to get the royalty percentage for a recipient.
(define-read-only (get-royalty-percentage (recipient principal))
  (ok (default-to u0 (map-get? royalty-recipients recipient))))

;; Read-only function to get the total distributed amount in the current block.
(define-read-only (get-total-distributed)
  (ok (default-to u0 (map-get? total-distributed block-height))))

;; Read-only function to get the number of recipients.
(define-read-only (get-num-recipients)
  (ok (var-get num-recipients)))

;; Read-only function to get a recipient by their index in the recipient list.
(define-read-only (get-recipient-by-index (index uint))
  (ok (map-get? recipient-list index)))
