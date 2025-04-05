;; Skill Certification Contract
;; Verifies specific competencies through testing

(define-data-var last-certification-id uint u0)
(define-data-var last-test-id uint u0)

;; Map of certification types
(define-map certification-types
  { id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 500),
    issuer: principal,
    created-at: uint,
    active: bool
  }
)

;; Map of certification tests
(define-map certification-tests
  { certification-type-id: uint, test-id: uint }
  {
    name: (string-utf8 100),
    description: (string-utf8 300),
    passing-score: uint, ;; Percentage (0-100)
    active: bool
  }
)

;; Map of issued certifications
(define-map issued-certifications
  { id: uint }
  {
    certification-type-id: uint,
    freelancer-id: uint,
    test-id: uint,
    score: uint,
    issued-at: uint,
    expires-at: (optional uint),
    revoked: bool
  }
)

;; Map of freelancer certifications
(define-map freelancer-certifications
  { freelancer-id: uint, certification-id: uint }
  { exists: bool }
)

;; Track certification count per freelancer
(define-map freelancer-certification-count
  { freelancer-id: uint }
  { count: uint }
)

;; Track test count per certification type
(define-map certification-test-count
  { certification-type-id: uint }
  { count: uint }
)

;; Create a new certification type
(define-public (create-certification-type
  (name (string-utf8 100))
  (description (string-utf8 500)))
  (let
    (
      (new-id (+ (var-get last-certification-id) u1))
    )
    (map-set certification-types
      { id: new-id }
      {
        name: name,
        description: description,
        issuer: tx-sender,
        created-at: block-height,
        active: true
      }
    )
    (map-set certification-test-count { certification-type-id: new-id } { count: u0 })
    (var-set last-certification-id new-id)
    (ok new-id)
  )
)

;; Create a test for a certification type
(define-public (create-certification-test
  (certification-type-id uint)
  (name (string-utf8 100))
  (description (string-utf8 300))
  (passing-score uint))
  (let
    (
      (cert-type (unwrap! (map-get? certification-types { id: certification-type-id }) (err u2)))
      (test-count-data (default-to { count: u0 } (map-get? certification-test-count { certification-type-id: certification-type-id })))
      (new-test-id (get count test-count-data))
    )
    ;; Only issuer can create tests
    (asserts! (is-eq tx-sender (get issuer cert-type)) (err u3))
    ;; Verify certification type is active
    (asserts! (get active cert-type) (err u4))
    ;; Verify passing score is between 0 and 100
    (asserts! (<= passing-score u100) (err u5))

    (map-set certification-tests
      { certification-type-id: certification-type-id, test-id: new-test-id }
      {
        name: name,
        description: description,
        passing-score: passing-score,
        active: true
      }
    )
    (map-set certification-test-count { certification-type-id: certification-type-id } { count: (+ new-test-id u1) })
    (var-set last-test-id (+ (var-get last-test-id) u1))
    (ok new-test-id)
  )
)

;; Issue a certification to a freelancer
(define-public (issue-certification
  (certification-type-id uint)
  (freelancer-id uint)
  (test-id uint)
  (score uint)
  (expires-at (optional uint)))
  (let
    (
      (new-id (+ (var-get last-certification-id) u1))
      (cert-type (unwrap! (map-get? certification-types { id: certification-type-id }) (err u2)))
      (test (unwrap! (map-get? certification-tests { certification-type-id: certification-type-id, test-id: test-id }) (err u6)))
    )
    ;; Only issuer can issue certifications
    (asserts! (is-eq tx-sender (get issuer cert-type)) (err u3))
    ;; Verify certification type is active
    (asserts! (get active cert-type) (err u4))
    ;; Verify test is active
    (asserts! (get active test) (err u7))
    ;; Verify score is between 0 and 100
    (asserts! (<= score u100) (err u5))
    ;; Verify score meets passing threshold
    (asserts! (>= score (get passing-score test)) (err u8))

    ;; Issue certification
    (map-set issued-certifications
      { id: new-id }
      {
        certification-type-id: certification-type-id,
        freelancer-id: freelancer-id,
        test-id: test-id,
        score: score,
        issued-at: block-height,
        expires-at: expires-at,
        revoked: false
      }
    )

    ;; Update freelancer certification list
    (let
      (
        (cert-count (default-to { count: u0 } (map-get? freelancer-certification-count { freelancer-id: freelancer-id })))
        (current-count (get count cert-count))
      )
      (map-set freelancer-certifications
        { freelancer-id: freelancer-id, certification-id: new-id }
        { exists: true }
      )
      (map-set freelancer-certification-count
        { freelancer-id: freelancer-id }
        { count: (+ current-count u1) }
      )
    )

    (ok new-id)
  )
)

;; Revoke a certification
(define-public (revoke-certification (certification-id uint))
  (let
    (
      (certification (unwrap! (map-get? issued-certifications { id: certification-id }) (err u2)))
      (cert-type (unwrap! (map-get? certification-types { id: (get certification-type-id certification) }) (err u9)))
    )
    ;; Only issuer can revoke certifications
    (asserts! (is-eq tx-sender (get issuer cert-type)) (err u3))

    ;; Revoke certification
    (map-set issued-certifications
      { id: certification-id }
      (merge certification { revoked: true })
    )

    (ok true)
  )
)

;; Read-only functions

;; Get certification type by ID
(define-read-only (get-certification-type (certification-type-id uint))
  (map-get? certification-types { id: certification-type-id })
)

;; Get certification test by ID
(define-read-only (get-certification-test (certification-type-id uint) (test-id uint))
  (map-get? certification-tests { certification-type-id: certification-type-id, test-id: test-id })
)

;; Get issued certification by ID
(define-read-only (get-certification (certification-id uint))
  (map-get? issued-certifications { id: certification-id })
)

;; Check if a certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (match (map-get? issued-certifications { id: certification-id })
    certification (and
                    (not (get revoked certification))
                    (match (get expires-at certification)
                      expiry (< block-height expiry)
                      true
                    )
                  )
    false
  )
)

;; Get certification count for a freelancer
(define-read-only (get-freelancer-certification-count (freelancer-id uint))
  (default-to { count: u0 } (map-get? freelancer-certification-count { freelancer-id: freelancer-id }))
)

;; Get test count for a certification type
(define-read-only (get-certification-test-count (certification-type-id uint))
  (default-to { count: u0 } (map-get? certification-test-count { certification-type-id: certification-type-id }))
)

