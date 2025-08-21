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
