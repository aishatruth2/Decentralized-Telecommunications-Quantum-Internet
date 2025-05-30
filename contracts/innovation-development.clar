;; Innovation Development Contract
;; Advances quantum internet technology

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u500))
(define-constant err-invalid-proposal (err u501))
(define-constant err-insufficient-funding (err u502))
(define-constant err-proposal-exists (err u503))

;; Innovation data structures
(define-map research-proposals uint {
    title: (string-ascii 100),
    researcher: principal,
    funding-required: uint,
    funding-received: uint,
    status: (string-ascii 20),
    innovation-type: (string-ascii 30),
    expected-impact: uint,
    submission-time: uint
})

(define-map innovation-milestones uint {
    proposal-id: uint,
    milestone-name: (string-ascii 50),
    completion-date: uint,
    impact-score: uint,
    verified: bool
})

(define-map researcher-profiles principal {
    name: (string-ascii 50),
    expertise-area: (string-ascii 30),
    completed-projects: uint,
    reputation-score: uint,
    total-funding: uint
})

(define-data-var proposal-counter uint u0)
(define-data-var milestone-counter uint u0)
(define-data-var innovation-fund uint u1000000)

;; Public functions
(define-public (submit-proposal
    (title (string-ascii 100))
    (funding-required uint)
    (innovation-type (string-ascii 30))
    (expected-impact uint))
    (let ((proposal-id (+ (var-get proposal-counter) u1))
          (researcher tx-sender))
        (map-set research-proposals proposal-id {
            title: title,
            researcher: researcher,
            funding-required: funding-required,
            funding-received: u0,
            status: "submitted",
            innovation-type: innovation-type,
            expected-impact: expected-impact,
            submission-time: block-height
        })
        (var-set proposal-counter proposal-id)
        (ok proposal-id)
    )
)

(define-public (fund-proposal (proposal-id uint) (amount uint))
    (let ((proposal (unwrap! (map-get? research-proposals proposal-id) err-invalid-proposal)))
        (asserts! (<= amount (var-get innovation-fund)) err-insufficient-funding)
        (map-set research-proposals proposal-id
            (merge proposal {
                funding-received: (+ (get funding-received proposal) amount),
                status: (if (>= (+ (get funding-received proposal) amount)
                               (get funding-required proposal))
                           "funded"
                           "partially-funded")
            }))
        (var-set innovation-fund (- (var-get innovation-fund) amount))
        (ok amount)
    )
)

(define-public (register-researcher
    (name (string-ascii 50))
    (expertise-area (string-ascii 30)))
    (let ((researcher tx-sender))
        (map-set researcher-profiles researcher {
            name: name,
            expertise-area: expertise-area,
            completed-projects: u0,
            reputation-score: u50,
            total-funding: u0
        })
        (ok researcher)
    )
)

(define-public (complete-milestone
    (proposal-id uint)
    (milestone-name (string-ascii 50))
    (impact-score uint))
    (let ((milestone-id (+ (var-get milestone-counter) u1))
          (proposal (unwrap! (map-get? research-proposals proposal-id) err-invalid-proposal)))
        (asserts! (is-eq tx-sender (get researcher proposal)) err-owner-only)
        (map-set innovation-milestones milestone-id {
            proposal-id: proposal-id,
            milestone-name: milestone-name,
            completion-date: block-height,
            impact-score: impact-score,
            verified: false
        })
        (var-set milestone-counter milestone-id)
        (ok milestone-id)
    )
)

(define-public (verify-milestone (milestone-id uint))
    (let ((milestone (unwrap! (map-get? innovation-milestones milestone-id) err-invalid-proposal)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set innovation-milestones milestone-id
            (merge milestone {verified: true}))
        ;; Update researcher reputation
        (let ((proposal (unwrap-panic (map-get? research-proposals (get proposal-id milestone))))
              (researcher (get researcher proposal)))
            (map-set researcher-profiles researcher
                (merge (default-to {name: "", expertise-area: "", completed-projects: u0, reputation-score: u50, total-funding: u0}
                       (map-get? researcher-profiles researcher))
                       {reputation-score: (+ (get reputation-score
                           (default-to {name: "", expertise-area: "", completed-projects: u0, reputation-score: u50, total-funding: u0}
                            (map-get? researcher-profiles researcher))) (get impact-score milestone))})))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-proposal (proposal-id uint))
    (map-get? research-proposals proposal-id)
)

(define-read-only (get-milestone (milestone-id uint))
    (map-get? innovation-milestones milestone-id)
)

(define-read-only (get-researcher-profile (researcher principal))
    (map-get? researcher-profiles researcher)
)

(define-read-only (get-innovation-fund-balance)
    (var-get innovation-fund)
)

(define-read-only (get-total-proposals)
    (var-get proposal-counter)
)

(define-read-only (calculate-innovation-score (proposal-id uint))
    (match (map-get? research-proposals proposal-id)
        proposal (let ((funding-ratio (/ (* (get funding-received proposal) u100)
                                        (get funding-required proposal)))
                      (impact (get expected-impact proposal)))
                    (+ funding-ratio impact))
        u0
    )
)
