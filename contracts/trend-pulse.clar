;; Define token for staking and rewards
(define-fungible-token pulse-token)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant min-stake-amount u100)
(define-constant voting-period u144) ;; ~24 hours in blocks
(define-constant max-trend-length u50)

;; Error codes
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-stake (err u101))
(define-constant err-trend-exists (err u102))
(define-constant err-invalid-trend (err u103))
(define-constant err-voting-ended (err u104))

;; Data structures
(define-map trends 
  { trend-id: uint }
  {
    creator: principal,
    name: (string-ascii 50),
    description: (string-ascii 200),
    created-at: uint,
    votes: uint,
    status: (string-ascii 10),
    stake-amount: uint
  }
)

(define-map votes
  { trend-id: uint, voter: principal }
  { vote-weight: uint }
)

;; Data variables
(define-data-var trend-counter uint u0)

;; Create new trend
(define-public (create-trend (name (string-ascii 50)) 
                           (description (string-ascii 200))
                           (stake-amount uint))
  (let ((trend-id (+ (var-get trend-counter) u1)))
    (asserts! (>= stake-amount min-stake-amount) err-insufficient-stake)
    (try! (ft-transfer? pulse-token stake-amount tx-sender (as-contract tx-sender)))
    (map-set trends
      { trend-id: trend-id }
      {
        creator: tx-sender,
        name: name,
        description: description,
        created-at: block-height,
        votes: u0,
        status: "active",
        stake-amount: stake-amount
      }
    )
    (var-set trend-counter trend-id)
    (ok trend-id)
  )
)

;; Vote on trend
(define-public (vote-on-trend (trend-id uint) (vote-weight uint))
  (let ((trend (unwrap! (map-get? trends { trend-id: trend-id }) err-invalid-trend)))
    (asserts! (< (- block-height (get created-at trend)) voting-period) err-voting-ended)
    (map-set votes
      { trend-id: trend-id, voter: tx-sender }
      { vote-weight: vote-weight }
    )
    (ok true)
  )
)

;; Get trend details
(define-read-only (get-trend (trend-id uint))
  (map-get? trends { trend-id: trend-id })
)

;; Get vote count
(define-read-only (get-vote-count (trend-id uint))
  (default-to u0 (get votes (map-get? trends { trend-id: trend-id })))
)
