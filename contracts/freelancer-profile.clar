;; Freelancer Profile Contract
;; Stores professional information, skills, and work experience for freelancers

(define-data-var last-id uint u0)

;; Map of freelancer profiles by ID
(define-map freelancers
  { id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    bio: (string-utf8 500),
    contact: (string-utf8 100),
    date-registered: uint,
    active: bool
  }
)

;; Map of freelancer IDs by owner
(define-map freelancer-by-owner
  { owner: principal }
  { id: uint }
)

;; Map of skills by freelancer ID
(define-map freelancer-skills
  { freelancer-id: uint, skill-id: uint }
  {
    skill-name: (string-utf8 50),
    years-experience: uint,
    level: (string-utf8 20) ;; "Beginner", "Intermediate", "Expert"
  }
)

;; Map of work experiences by freelancer ID
(define-map work-experiences
  { freelancer-id: uint, experience-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 500),
    start-date: uint,
    end-date: uint,
    verified: bool
  }
)

;; Track skills count per freelancer
(define-map freelancer-skill-count
  { freelancer-id: uint }
  { count: uint }
)

;; Track experience count per freelancer
(define-map freelancer-experience-count
  { freelancer-id: uint }
  { count: uint }
)

;; Create a new freelancer profile
(define-public (register-freelancer (name (string-utf8 100)) (bio (string-utf8 500)) (contact (string-utf8 100)))
  (let
    (
      (new-id (+ (var-get last-id) u1))
    )
    (asserts! (is-none (map-get? freelancer-by-owner { owner: tx-sender })) (err u1)) ;; Ensure one profile per address
    (map-set freelancers
      { id: new-id }
      {
        owner: tx-sender,
        name: name,
        bio: bio,
        contact: contact,
        date-registered: block-height,
        active: true
      }
    )
    ;; Store the mapping from owner to ID
    (map-set freelancer-by-owner { owner: tx-sender } { id: new-id })
    (map-set freelancer-skill-count { freelancer-id: new-id } { count: u0 })
    (map-set freelancer-experience-count { freelancer-id: new-id } { count: u0 })
    (var-set last-id new-id)
    (ok new-id)
  )
)

;; Update freelancer profile
(define-public (update-profile (id uint) (name (string-utf8 100)) (bio (string-utf8 500)) (contact (string-utf8 100)))
  (let
    (
      (profile (unwrap! (map-get? freelancers { id: id }) (err u2)))
    )
    (asserts! (is-eq tx-sender (get owner profile)) (err u3)) ;; Only owner can update
    (map-set freelancers
      { id: id }
      (merge profile { name: name, bio: bio, contact: contact })
    )
    (ok true)
  )
)

;; Add a skill to freelancer profile
(define-public (add-skill (freelancer-id uint) (skill-name (string-utf8 50)) (years-experience uint) (level (string-utf8 20)))
  (let
    (
      (profile (unwrap! (map-get? freelancers { id: freelancer-id }) (err u2)))
      (skill-count-data (default-to { count: u0 } (map-get? freelancer-skill-count { freelancer-id: freelancer-id })))
      (new-skill-id (get count skill-count-data))
    )
    (asserts! (is-eq tx-sender (get owner profile)) (err u3)) ;; Only owner can add skills
    (map-set freelancer-skills
      { freelancer-id: freelancer-id, skill-id: new-skill-id }
      { skill-name: skill-name, years-experience: years-experience, level: level }
    )
    (map-set freelancer-skill-count { freelancer-id: freelancer-id } { count: (+ new-skill-id u1) })
    (ok new-skill-id)
  )
)

;; Add work experience
(define-public (add-experience (freelancer-id uint) (title (string-utf8 100)) (description (string-utf8 500)) (start-date uint) (end-date uint))
  (let
    (
      (profile (unwrap! (map-get? freelancers { id: freelancer-id }) (err u2)))
      (exp-count-data (default-to { count: u0 } (map-get? freelancer-experience-count { freelancer-id: freelancer-id })))
      (new-exp-id (get count exp-count-data))
    )
    (asserts! (is-eq tx-sender (get owner profile)) (err u3)) ;; Only owner can add experience
    (map-set work-experiences
      { freelancer-id: freelancer-id, experience-id: new-exp-id }
      {
        title: title,
        description: description,
        start-date: start-date,
        end-date: end-date,
        verified: false
      }
    )
    (map-set freelancer-experience-count { freelancer-id: freelancer-id } { count: (+ new-exp-id u1) })
    (ok new-exp-id)
  )
)

;; Deactivate freelancer profile
(define-public (deactivate-profile (id uint))
  (let
    (
      (profile (unwrap! (map-get? freelancers { id: id }) (err u2)))
    )
    (asserts! (is-eq tx-sender (get owner profile)) (err u3)) ;; Only owner can deactivate
    (map-set freelancers
      { id: id }
      (merge profile { active: false })
    )
    (ok true)
  )
)

;; Reactivate freelancer profile
(define-public (reactivate-profile (id uint))
  (let
    (
      (profile (unwrap! (map-get? freelancers { id: id }) (err u2)))
    )
    (asserts! (is-eq tx-sender (get owner profile)) (err u3)) ;; Only owner can reactivate
    (map-set freelancers
      { id: id }
      (merge profile { active: true })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get freelancer by ID
(define-read-only (get-freelancer (id uint))
  (map-get? freelancers { id: id })
)

;; Get freelancer by owner address
(define-read-only (get-freelancer-by-owner (owner principal))
  (map-get? freelancer-by-owner { owner: owner })
)

;; Get skill by ID
(define-read-only (get-skill (freelancer-id uint) (skill-id uint))
  (map-get? freelancer-skills { freelancer-id: freelancer-id, skill-id: skill-id })
)

;; Get experience by ID
(define-read-only (get-experience (freelancer-id uint) (experience-id uint))
  (map-get? work-experiences { freelancer-id: freelancer-id, experience-id: experience-id })
)

;; Get all skills for a freelancer
(define-read-only (get-skill-count (freelancer-id uint))
  (default-to { count: u0 } (map-get? freelancer-skill-count { freelancer-id: freelancer-id }))
)

;; Get all experiences for a freelancer
(define-read-only (get-experience-count (freelancer-id uint))
  (default-to { count: u0 } (map-get? freelancer-experience-count { freelancer-id: freelancer-id }))
)

