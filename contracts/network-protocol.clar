;; Network Protocol Contract
;; Manages quantum communication protocols

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-invalid-protocol (err u201))
(define-constant err-protocol-exists (err u202))
(define-constant err-unauthorized (err u203))

;; Protocol data structures
(define-map quantum-protocols uint {
    name: (string-ascii 30),
    version: (string-ascii 10),
    encryption-type: (string-ascii 20),
    max-distance: uint,
    fidelity-threshold: uint,
    active: bool
})

(define-map protocol-usage uint {
    connections-count: uint,
    data-transmitted: uint,
    last-used: uint
})

(define-data-var protocol-counter uint u0)
(define-data-var active-connections uint u0)

;; Public functions
(define-public (register-protocol
    (name (string-ascii 30))
    (version (string-ascii 10))
    (encryption-type (string-ascii 20))
    (max-distance uint)
    (fidelity-threshold uint))
    (let ((protocol-id (+ (var-get protocol-counter) u1)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set quantum-protocols protocol-id {
            name: name,
            version: version,
            encryption-type: encryption-type,
            max-distance: max-distance,
            fidelity-threshold: fidelity-threshold,
            active: true
        })
        (map-set protocol-usage protocol-id {
            connections-count: u0,
            data-transmitted: u0,
            last-used: u0
        })
        (var-set protocol-counter protocol-id)
        (ok protocol-id)
    )
)

(define-public (establish-connection (protocol-id uint) (distance uint))
    (let ((protocol (unwrap! (map-get? quantum-protocols protocol-id) err-invalid-protocol)))
        (asserts! (get active protocol) err-invalid-protocol)
        (asserts! (<= distance (get max-distance protocol)) err-invalid-protocol)
        (map-set protocol-usage protocol-id
            (merge (default-to {connections-count: u0, data-transmitted: u0, last-used: u0}
                   (map-get? protocol-usage protocol-id))
                   {connections-count: (+ (get connections-count
                       (default-to {connections-count: u0, data-transmitted: u0, last-used: u0}
                        (map-get? protocol-usage protocol-id))) u1),
                    last-used: block-height}))
        (var-set active-connections (+ (var-get active-connections) u1))
        (ok true)
    )
)

(define-public (transmit-data (protocol-id uint) (data-size uint))
    (let ((protocol (unwrap! (map-get? quantum-protocols protocol-id) err-invalid-protocol)))
        (asserts! (get active protocol) err-invalid-protocol)
        (map-set protocol-usage protocol-id
            (merge (default-to {connections-count: u0, data-transmitted: u0, last-used: u0}
                   (map-get? protocol-usage protocol-id))
                   {data-transmitted: (+ (get data-transmitted
                       (default-to {connections-count: u0, data-transmitted: u0, last-used: u0}
                        (map-get? protocol-usage protocol-id))) data-size)}))
        (ok data-size)
    )
)

;; Read-only functions
(define-read-only (get-protocol (protocol-id uint))
    (map-get? quantum-protocols protocol-id)
)

(define-read-only (get-protocol-usage (protocol-id uint))
    (map-get? protocol-usage protocol-id)
)

(define-read-only (get-active-connections)
    (var-get active-connections)
)

(define-read-only (get-total-protocols)
    (var-get protocol-counter)
)
