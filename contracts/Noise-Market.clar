;; title: Noise-Market
;; version: 1.0.0
;; summary: A market for trading random on-chain data streams
;; description: Users can create noise streams, place buy/sell orders, and trade random data

;; constants
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-STREAM-NOT-FOUND (err u103))
(define-constant ERR-ORDER-NOT-FOUND (err u104))
(define-constant ERR-ORDER-EXPIRED (err u105))
(define-constant CONTRACT-OWNER tx-sender)

;; data vars
(define-data-var next-stream-id uint u1)
(define-data-var next-order-id uint u1)

;; data maps
(define-map noise-streams 
  uint 
  {
    creator: principal,
    name: (string-ascii 50),
    price: uint,
    data-hash: (buff 32),
    block-height: uint,
    active: bool
  }
)

(define-map user-balances 
  principal 
  uint
)

(define-map buy-orders 
  uint 
  {
    buyer: principal,
    stream-id: uint,
    amount: uint,
    price: uint,
    expires-at: uint
  }
)

(define-map sell-orders 
  uint 
  {
    seller: principal,
    stream-id: uint,
    amount: uint,
    price: uint,
    expires-at: uint
  }
)

(define-map user-streams 
  principal 
  (list 100 uint)
)

;; public functions

(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (match (stx-transfer? amount tx-sender (as-contract tx-sender))
      success (ok (map-set user-balances tx-sender 
                    (+ (default-to u0 (map-get? user-balances tx-sender)) amount)))
      error ERR-INSUFFICIENT-BALANCE)))

(define-public (withdraw (amount uint))
  (let ((current-balance (default-to u0 (map-get? user-balances tx-sender))))
    (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
    (match (as-contract (stx-transfer? amount tx-sender tx-sender))
      success (ok (map-set user-balances tx-sender (- current-balance amount)))
      error ERR-INSUFFICIENT-BALANCE)))

(define-public (create-noise-stream (name (string-ascii 50)) (price uint))
  (let ((stream-id (var-get next-stream-id))
        (random-data (keccak256 (concat (unwrap-panic (to-consensus-buff? block-height))
                                       (unwrap-panic (to-consensus-buff? tx-sender))))))
    (asserts! (> price u0) ERR-INVALID-AMOUNT)
    (map-set noise-streams stream-id 
      {
        creator: tx-sender,
        name: name,
        price: price,
        data-hash: random-data,
        block-height: block-height,
        active: true
      })
    (var-set next-stream-id (+ stream-id u1))
    (ok stream-id)))

(define-public (create-buy-order (stream-id uint) (amount uint) (price uint) (expires-in uint))
  (let ((order-id (var-get next-order-id))
        (user-balance (default-to u0 (map-get? user-balances tx-sender)))
        (total-cost (* amount price)))
    (asserts! (is-some (map-get? noise-streams stream-id)) ERR-STREAM-NOT-FOUND)
    (asserts! (>= user-balance total-cost) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (map-set buy-orders order-id 
      {
        buyer: tx-sender,
        stream-id: stream-id,
        amount: amount,
        price: price,
        expires-at: (+ block-height expires-in)
      })
    (map-set user-balances tx-sender (- user-balance total-cost))
    (var-set next-order-id (+ order-id u1))
    (ok order-id)))

(define-public (create-sell-order (stream-id uint) (amount uint) (price uint) (expires-in uint))
  (let ((order-id (var-get next-order-id)))
    (asserts! (is-some (map-get? noise-streams stream-id)) ERR-STREAM-NOT-FOUND)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (map-set sell-orders order-id 
      {
        seller: tx-sender,
        stream-id: stream-id,
        amount: amount,
        price: price,
        expires-at: (+ block-height expires-in)
      })
    (var-set next-order-id (+ order-id u1))
    (ok order-id)))

(define-public (fulfill-buy-order (order-id uint))
  (let ((order (unwrap! (map-get? buy-orders order-id) ERR-ORDER-NOT-FOUND)))
    (asserts! (<= block-height (get expires-at order)) ERR-ORDER-EXPIRED)
    (let ((stream (unwrap! (map-get? noise-streams (get stream-id order)) ERR-STREAM-NOT-FOUND))
          (seller-balance (default-to u0 (map-get? user-balances tx-sender)))
          (buyer-balance (default-to u0 (map-get? user-balances (get buyer order))))
          (total-payment (* (get amount order) (get price order))))
      (asserts! (get active stream) ERR-STREAM-NOT-FOUND)
      (map-set user-balances tx-sender (+ seller-balance total-payment))
      (map-delete buy-orders order-id)
      (ok true))))

(define-public (fulfill-sell-order (order-id uint))
  (let ((order (unwrap! (map-get? sell-orders order-id) ERR-ORDER-NOT-FOUND)))
    (asserts! (<= block-height (get expires-at order)) ERR-ORDER-EXPIRED)
    (let ((stream (unwrap! (map-get? noise-streams (get stream-id order)) ERR-STREAM-NOT-FOUND))
          (buyer-balance (default-to u0 (map-get? user-balances tx-sender)))
          (seller-balance (default-to u0 (map-get? user-balances (get seller order))))
          (total-cost (* (get amount order) (get price order))))
      (asserts! (get active stream) ERR-STREAM-NOT-FOUND)
      (asserts! (>= buyer-balance total-cost) ERR-INSUFFICIENT-BALANCE)
      (map-set user-balances tx-sender (- buyer-balance total-cost))
      (map-set user-balances (get seller order) (+ seller-balance total-cost))
      (map-delete sell-orders order-id)
      (ok true))))

(define-public (cancel-buy-order (order-id uint))
  (let ((order (unwrap! (map-get? buy-orders order-id) ERR-ORDER-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get buyer order)) ERR-NOT-AUTHORIZED)
    (let ((refund (* (get amount order) (get price order)))
          (current-balance (default-to u0 (map-get? user-balances tx-sender))))
      (map-set user-balances tx-sender (+ current-balance refund))
      (map-delete buy-orders order-id)
      (ok true))))

(define-public (cancel-sell-order (order-id uint))
  (let ((order (unwrap! (map-get? sell-orders order-id) ERR-ORDER-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get seller order)) ERR-NOT-AUTHORIZED)
    (map-delete sell-orders order-id)
    (ok true)))

;; read only functions

(define-read-only (get-noise-stream (stream-id uint))
  (map-get? noise-streams stream-id))

(define-read-only (get-user-balance (user principal))
  (default-to u0 (map-get? user-balances user)))

(define-read-only (get-buy-order (order-id uint))
  (map-get? buy-orders order-id))

(define-read-only (get-sell-order (order-id uint))
  (map-get? sell-orders order-id))

(define-read-only (get-next-stream-id)
  (var-get next-stream-id))

(define-read-only (get-next-order-id)
  (var-get next-order-id))

(define-read-only (generate-noise-data (seed uint))
  (keccak256 (concat (unwrap-panic (to-consensus-buff? seed))
                     (unwrap-panic (to-consensus-buff? block-height)))))
