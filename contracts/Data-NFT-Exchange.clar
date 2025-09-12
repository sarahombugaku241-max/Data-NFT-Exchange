(define-non-fungible-token data-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-PRICE (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-ROYALTY (err u403))
(define-constant ERR-LICENSE-EXPIRED (err u410))
(define-constant ERR-ACCESS-DENIED (err u403))

(define-data-var next-token-id uint u1)
(define-data-var contract-owner principal tx-sender)

(define-map data-metadata 
    uint 
    {
        creator: principal,
        name: (string-ascii 64),
        description: (string-ascii 256),
        data-hash: (buff 32),
        category: (string-ascii 32),
        size-bytes: uint,
        created-at: uint,
        royalty-percent: uint,
        base-price: uint,
        verification-status: bool
    }
)

(define-map data-licenses
    {token-id: uint, licensee: principal}
    {
        license-type: (string-ascii 32),
        expires-at: uint,
        price-paid: uint,
        usage-rights: (string-ascii 128),
        granted-at: uint
    }
)

(define-map token-prices
    uint
    {
        sale-price: uint,
        for-sale: bool,
        seller: principal
    }
)

(define-map royalty-earnings
    principal
    uint
)

(define-map access-permissions
    {token-id: uint, accessor: principal}
    {
        permission-type: (string-ascii 32),
        granted-by: principal,
        granted-at: uint,
        expires-at: uint
    }
)

(define-map data-verification
    uint
    {
        verifier: principal,
        verified-at: uint,
        verification-hash: (buff 32),
        trust-score: uint
    }
)

(define-map usage-analytics
    uint
    {
        total-views: uint,
        total-licenses: uint,
        total-revenue: uint,
        last-accessed: uint,
        unique-viewers: uint,
        trending-score: uint
    }
)

(define-map user-activity
    {token-id: uint, user: principal}
    {
        view-count: uint,
        last-viewed: uint,
        total-spent: uint,
        interaction-type: (string-ascii 16)
    }
)

(define-map daily-stats
    {token-id: uint, day: uint}
    {
        views: uint,
        licenses: uint,
        revenue: uint,
        unique-users: uint
    }
)

(define-public (mint-data-nft 
    (name (string-ascii 64))
    (description (string-ascii 256))
    (data-hash (buff 32))
    (category (string-ascii 32))
    (size-bytes uint)
    (royalty-percent uint)
    (base-price uint)
)
    (let ((token-id (var-get next-token-id)))
        (asserts! (<= royalty-percent u25) ERR-INVALID-ROYALTY)
        (asserts! (> base-price u0) ERR-INVALID-PRICE)
        (try! (nft-mint? data-nft token-id tx-sender))
        (map-set data-metadata token-id {
            creator: tx-sender,
            name: name,
            description: description,
            data-hash: data-hash,
            category: category,
            size-bytes: size-bytes,
            created-at: stacks-block-height,
            royalty-percent: royalty-percent,
            base-price: base-price,
            verification-status: false
        })
        (map-set usage-analytics token-id {
            total-views: u0,
            total-licenses: u0,
            total-revenue: u0,
            last-accessed: stacks-block-height,
            unique-viewers: u0,
            trending-score: u0
        })
        (var-set next-token-id (+ token-id u1))
        (ok token-id)
    )
)

(define-public (verify-data (token-id uint) (verification-hash (buff 32)) (trust-score uint))
    (let ((metadata (unwrap! (map-get? data-metadata token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= trust-score u100) ERR-INVALID-PRICE)
        (map-set data-verification token-id {
            verifier: tx-sender,
            verified-at: stacks-block-height,
            verification-hash: verification-hash,
            trust-score: trust-score
        })
        (map-set data-metadata token-id (merge metadata {verification-status: true}))
        (ok true)
    )
)

(define-public (list-for-sale (token-id uint) (sale-price uint))
    (let ((owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> sale-price u0) ERR-INVALID-PRICE)
        (map-set token-prices token-id {
            sale-price: sale-price,
            for-sale: true,
            seller: tx-sender
        })
        (ok true)
    )
)

(define-public (remove-from-sale (token-id uint))
    (let ((owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
        (map-delete token-prices token-id)
        (ok true)
    )
)

(define-public (purchase-nft (token-id uint))
    (let 
        (
            (price-info (unwrap! (map-get? token-prices token-id) ERR-NOT-FOUND))
            (metadata (unwrap! (map-get? data-metadata token-id) ERR-NOT-FOUND))
            (sale-price (get sale-price price-info))
            (seller (get seller price-info))
            (royalty-amount (/ (* sale-price (get royalty-percent metadata)) u100))
            (seller-amount (- sale-price royalty-amount))
        )
        (asserts! (get for-sale price-info) ERR-NOT-FOUND)
        (asserts! (>= (stx-get-balance tx-sender) sale-price) ERR-INSUFFICIENT-BALANCE)
        
        (try! (stx-transfer? seller-amount tx-sender seller))
        (try! (stx-transfer? royalty-amount tx-sender (get creator metadata)))
        (try! (nft-transfer? data-nft token-id seller tx-sender))
        
        (map-delete token-prices token-id)
        (map-set royalty-earnings (get creator metadata) 
            (+ (default-to u0 (map-get? royalty-earnings (get creator metadata))) royalty-amount))
        (ok true)
    )
)

(define-public (license-data 
    (token-id uint) 
    (license-type (string-ascii 32))
    (duration-blocks uint)
    (usage-rights (string-ascii 128))
)
    (let 
        (
            (metadata (unwrap! (map-get? data-metadata token-id) ERR-NOT-FOUND))
            (license-price (get base-price metadata))
            (expires-at (+ stacks-block-height duration-blocks))
            (royalty-amount (/ (* license-price (get royalty-percent metadata)) u100))
            (owner-amount (- license-price royalty-amount))
            (owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND))
            (current-analytics (default-to {
                total-views: u0,
                total-licenses: u0,
                total-revenue: u0,
                last-accessed: u0,
                unique-viewers: u0,
                trending-score: u0
            } (map-get? usage-analytics token-id)))
            (current-user-activity (default-to {
                view-count: u0,
                last-viewed: u0,
                total-spent: u0,
                interaction-type: ""
            } (map-get? user-activity {token-id: token-id, user: tx-sender})))
            (current-day (/ stacks-block-height u144))
            (daily-data (default-to {
                views: u0,
                licenses: u0,
                revenue: u0,
                unique-users: u0
            } (map-get? daily-stats {token-id: token-id, day: current-day})))
        )
        (asserts! (>= (stx-get-balance tx-sender) license-price) ERR-INSUFFICIENT-BALANCE)
        (asserts! (get verification-status metadata) ERR-ACCESS-DENIED)
        
        (try! (stx-transfer? owner-amount tx-sender owner))
        (try! (stx-transfer? royalty-amount tx-sender (get creator metadata)))
        
        (map-set data-licenses {token-id: token-id, licensee: tx-sender} {
            license-type: license-type,
            expires-at: expires-at,
            price-paid: license-price,
            usage-rights: usage-rights,
            granted-at: stacks-block-height
        })
        (map-set royalty-earnings (get creator metadata) 
            (+ (default-to u0 (map-get? royalty-earnings (get creator metadata))) royalty-amount))
        
        (map-set usage-analytics token-id (merge current-analytics {
            total-licenses: (+ (get total-licenses current-analytics) u1),
            total-revenue: (+ (get total-revenue current-analytics) license-price),
            last-accessed: stacks-block-height,
            trending-score: (+ (get trending-score current-analytics) u10)
        }))
        (map-set user-activity {token-id: token-id, user: tx-sender} (merge current-user-activity {
            total-spent: (+ (get total-spent current-user-activity) license-price),
            last-viewed: stacks-block-height,
            interaction-type: "license"
        }))
        (map-set daily-stats {token-id: token-id, day: current-day} (merge daily-data {
            licenses: (+ (get licenses daily-data) u1),
            revenue: (+ (get revenue daily-data) license-price)
        }))
        (ok expires-at)
    )
)

(define-public (grant-access 
    (token-id uint) 
    (accessor principal) 
    (permission-type (string-ascii 32))
    (duration-blocks uint)
)
    (let ((owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
        (map-set access-permissions {token-id: token-id, accessor: accessor} {
            permission-type: permission-type,
            granted-by: tx-sender,
            granted-at: stacks-block-height,
            expires-at: (+ stacks-block-height duration-blocks)
        })
        (ok true)
    )
)

(define-public (revoke-access (token-id uint) (accessor principal))
    (let ((owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND)))
        (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
        (map-delete access-permissions {token-id: token-id, accessor: accessor})
        (ok true)
    )
)

(define-public (update-base-price (token-id uint) (new-price uint))
    (let 
        (
            (owner (unwrap! (nft-get-owner? data-nft token-id) ERR-NOT-FOUND))
            (metadata (unwrap! (map-get? data-metadata token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq owner tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        (map-set data-metadata token-id (merge metadata {base-price: new-price}))
        (ok true)
    )
)

(define-public (track-data-view (token-id uint))
    (let 
        (
            (metadata (unwrap! (map-get? data-metadata token-id) ERR-NOT-FOUND))
            (current-analytics (default-to {
                total-views: u0,
                total-licenses: u0,
                total-revenue: u0,
                last-accessed: u0,
                unique-viewers: u0,
                trending-score: u0
            } (map-get? usage-analytics token-id)))
            (current-user-activity (map-get? user-activity {token-id: token-id, user: tx-sender}))
            (is-new-viewer (is-none current-user-activity))
            (current-day (/ stacks-block-height u144))
            (daily-data (default-to {
                views: u0,
                licenses: u0,
                revenue: u0,
                unique-users: u0
            } (map-get? daily-stats {token-id: token-id, day: current-day})))
        )
        (map-set usage-analytics token-id (merge current-analytics {
            total-views: (+ (get total-views current-analytics) u1),
            last-accessed: stacks-block-height,
            unique-viewers: (+ (get unique-viewers current-analytics) (if is-new-viewer u1 u0)),
            trending-score: (+ (get trending-score current-analytics) u1)
        }))
        (map-set user-activity {token-id: token-id, user: tx-sender} {
            view-count: (+ (match current-user-activity
                activity (get view-count activity)
                u0
            ) u1),
            last-viewed: stacks-block-height,
            total-spent: (match current-user-activity
                activity (get total-spent activity)
                u0
            ),
            interaction-type: "view"
        })
        (map-set daily-stats {token-id: token-id, day: current-day} (merge daily-data {
            views: (+ (get views daily-data) u1),
            unique-users: (+ (get unique-users daily-data) (if is-new-viewer u1 u0))
        }))
        (ok true)
    )
)

(define-public (withdraw-royalties)
    (let ((earnings (default-to u0 (map-get? royalty-earnings tx-sender))))
        (asserts! (> earnings u0) ERR-INSUFFICIENT-BALANCE)
        (map-delete royalty-earnings tx-sender)
        (try! (as-contract (stx-transfer? earnings tx-sender tx-sender)))
        (ok earnings)
    )
)

(define-read-only (get-token-metadata (token-id uint))
    (map-get? data-metadata token-id)
)

(define-read-only (get-token-price (token-id uint))
    (map-get? token-prices token-id)
)

(define-read-only (get-license-info (token-id uint) (licensee principal))
    (map-get? data-licenses {token-id: token-id, licensee: licensee})
)

(define-read-only (get-access-permission (token-id uint) (accessor principal))
    (map-get? access-permissions {token-id: token-id, accessor: accessor})
)

(define-read-only (get-verification-info (token-id uint))
    (map-get? data-verification token-id)
)

(define-read-only (get-royalty-earnings (creator principal))
    (default-to u0 (map-get? royalty-earnings creator))
)

(define-read-only (has-valid-license (token-id uint) (licensee principal))
    (match (map-get? data-licenses {token-id: token-id, licensee: licensee})
        license-info (> (get expires-at license-info) stacks-block-height)
        false
    )
)

(define-read-only (has-valid-access (token-id uint) (accessor principal))
    (match (map-get? access-permissions {token-id: token-id, accessor: accessor})
        permission-info (> (get expires-at permission-info) stacks-block-height)
        false
    )
)

(define-read-only (get-next-token-id)
    (var-get next-token-id)
)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (get-token-uri (token-id uint))
    (ok (some "https://datanft.exchange/metadata/"))
)

(define-read-only (get-usage-analytics (token-id uint))
    (map-get? usage-analytics token-id)
)

(define-read-only (get-user-activity (token-id uint) (user principal))
    (map-get? user-activity {token-id: token-id, user: user})
)

(define-read-only (get-daily-stats (token-id uint) (day uint))
    (map-get? daily-stats {token-id: token-id, day: day})
)

(define-read-only (get-trending-score (token-id uint))
    (match (map-get? usage-analytics token-id)
        analytics (get trending-score analytics)
        u0
    )
)

(define-read-only (calculate-engagement-rate (token-id uint))
    (match (map-get? usage-analytics token-id)
        analytics (let 
            (
                (views (get total-views analytics))
                (licenses (get total-licenses analytics))
            )
            (if (> views u0)
                (/ (* licenses u100) views)
                u0
            )
        )
        u0
    )
)

(define-read-only (get-revenue-per-view (token-id uint))
    (match (map-get? usage-analytics token-id)
        analytics (let 
            (
                (revenue (get total-revenue analytics))
                (views (get total-views analytics))
            )
            (if (> views u0)
                (/ revenue views)
                u0
            )
        )
        u0
    )
)

(define-read-only (is-trending (token-id uint))
    (let ((score (get-trending-score token-id)))
        (> score u50)
    )
)
