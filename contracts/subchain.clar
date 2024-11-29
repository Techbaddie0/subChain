;; Decentralized Subscription Management Contract

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u1))
(define-constant err-insufficient-funds (err u2))
(define-constant err-subscription-not-found (err u3))
(define-constant err-already-subscribed (err u4))
(define-constant err-subscription-expired (err u5))

;; Subscription Struct
(define-map subscriptions 
  { 
    user: principal,
    service-id: uint 
  }
  {
    start-time: uint,
    end-time: uint,
    tier: (string-ascii 20),
    auto-renew: bool
  }
)

;; Service Catalog
(define-map services
  { service-id: uint }
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    monthly-price: uint,
    annual-price: uint
  }
)

;; Create a new service
(define-public (create-service 
  (service-id uint)
  (name (string-ascii 50))
  (description (string-ascii 200))
  (monthly-price uint)
  (annual-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (map-set services 
      { service-id: service-id }
      {
        name: name,
        description: description,
        monthly-price: monthly-price,
        annual-price: annual-price
      }
    )
    (ok true)
  )
)

;; Subscribe to a service
(define-public (subscribe 
  (service-id uint)
  (is-annual bool))
  (let 
    (
      (service (unwrap! (map-get? services { service-id: service-id }) err-subscription-not-found))
      (price (if is-annual 
                 (get annual-price service)
                 (get monthly-price service)))
      (duration (if is-annual 
                    (* u365 u86400) 
                    (* u30 u86400)))
      (current-time block-timestamp)
    )
    ;; Check if user is already subscribed
    (asserts! 
      (is-none (map-get? subscriptions 
        { 
          user: tx-sender, 
          service-id: service-id 
        })) 
      err-already-subscribed)
    
    ;; Record subscription
    (map-set subscriptions
      { 
        user: tx-sender, 
        service-id: service-id 
      }
      {
        start-time: current-time,
        end-time: (+ current-time duration),
        tier: (if is-annual "annual" "monthly"),
        auto-renew: true
      }
    )
    
    (ok true)
  )
)

;; Renew subscription
(define-public (renew-subscription 
  (service-id uint))
  (let 
    (
      (subscription (unwrap! 
        (map-get? subscriptions 
          { 
            user: tx-sender, 
            service-id: service-id 
          }) 
        err-subscription-not-found))
      (service (unwrap! 
        (map-get? services 
          { service-id: service-id }) 
        err-subscription-not-found))
      (current-time block-timestamp)
      (duration (if (is-eq (get tier subscription) "annual")
                    (* u365 u86400)
                    (* u30 u86400)))
    )
    ;; Validate subscription
    (asserts! 
      (>= (get end-time subscription) current-time) 
      err-subscription-expired)
    
    ;; Update subscription
    (map-set subscriptions
      { 
        user: tx-sender, 
        service-id: service-id 
      }
      {
        start-time: current-time,
        end-time: (+ current-time duration),
        tier: (get tier subscription),
        auto-renew: true
      }
    )
    
    (ok true)
  )
)

;; Check subscription status
(define-read-only (is-subscribed 
  (user principal)
  (service-id uint))
  (match (map-get? subscriptions 
          { 
            user: user, 
            service-id: service-id 
          })
    subscription 
      (>= (get end-time subscription) block-timestamp)
    false)
)

;; Get subscription details
(define-read-only (get-subscription-details 
  (user principal)
  (service-id uint))
  (map-get? subscriptions 
    { 
      user: user, 
      service-id: service-id 
    })
)