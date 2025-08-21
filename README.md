# 📊 Data NFT Exchange

> 🔐 **Empowering data privacy and monetization through blockchain technology**

A decentralized marketplace where users can mint their anonymized datasets as NFTs, license access with defined terms, and earn royalties on secondary usage. Built on Stacks blockchain with Clarity smart contracts.

## 🌟 Features

### 🎯 Core Functionality
- **🏷️ Data NFT Minting**: Convert datasets into verifiable NFTs with metadata
- **🔒 Privacy-Preserving Licensing**: License data access without exposing personal details  
- **💰 Automatic Royalties**: Smart contract enforced royalties on resales and usage
- **✅ Data Verification**: Trusted verification system with reputation scoring
- **🛡️ Access Control**: Granular permissions for data access and usage rights

### 💡 Key Benefits
- **👥 User Empowerment**: Individuals control and monetize their data
- **🏢 Enterprise Analytics**: Companies access verified datasets compliantly  
- **🔍 Privacy-First**: Analytics without compromising personal privacy
- **💸 Fair Compensation**: Creators earn from initial sales and ongoing usage

## 🚀 Quick Start

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation
```bash
git clone <repository-url>
cd Data-NFT-Exchange
clarinet check
npm install
npm test
```

## 📖 Usage Guide

### 🎨 Minting Data NFTs

```clarity
(contract-call? .Data-NFT-Exchange mint-data-nft 
  "Customer Demographics"                    ;; name
  "Anonymized customer purchase patterns"    ;; description  
  0x1234...                                 ;; data hash
  "analytics"                               ;; category
  u1048576                                  ;; size in bytes
  u10                                       ;; 10% royalty
  u1000000                                  ;; base price (microSTX)
)
```

### 🛒 Buying NFTs

```clarity
(contract-call? .Data-NFT-Exchange purchase-nft u1)
```

### 📄 Licensing Data Access

```clarity
(contract-call? .Data-NFT-Exchange license-data
  u1                                        ;; token ID
  "commercial"                              ;; license type
  u144000                                   ;; duration (blocks ~1 year)
  "analytics,reporting,insights"            ;; usage rights
)
```

### ✅ Data Verification

```clarity
(contract-call? .Data-NFT-Exchange verify-data
  u1                                        ;; token ID
  0x5678...                                 ;; verification hash
  u95                                       ;; trust score (0-100)
)
```

## 🔧 Smart Contract Functions

### 📝 Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `mint-data-nft` | Create new data NFT | name, description, hash, category, size, royalty%, price |
| `verify-data` | Verify data authenticity | token-id, verification-hash, trust-score |
| `list-for-sale` | List NFT for sale | token-id, sale-price |
| `purchase-nft` | Buy listed NFT | token-id |
| `license-data` | License data access | token-id, license-type, duration, usage-rights |
| `grant-access` | Grant specific permissions | token-id, accessor, permission-type, duration |
| `update-base-price` | Update licensing price | token-id, new-price |
| `withdraw-royalties` | Claim earned royalties | - |

### 📊 Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-token-metadata` | Get NFT metadata | Metadata object |
| `get-license-info` | Check license details | License information |
| `has-valid-license` | Verify active license | Boolean |
| `get-verification-info` | Get verification status | Verification details |
| `get-royalty-earnings` | Check royalty balance | Amount earned |

## 🏗️ Architecture

### 📦 Data Structures

- **🏷️ NFT Metadata**: Creator, name, description, hash, category, size, timestamps, pricing
- **📋 Licenses**: Type, expiration, pricing, usage rights, grant timestamps  
- **🎯 Access Permissions**: Permission types, grantor, duration, expiration
- **✅ Verification**: Verifier, trust scores, verification hashes
- **💰 Royalties**: Earnings tracking per creator

### 🔄 Workflow

1. **📤 Data Upload**: User uploads anonymized dataset
2. **🏷️ NFT Minting**: Dataset converted to NFT with metadata
3. **✅ Verification**: Optional third-party verification
4. **💰 Pricing**: Set base prices and royalty percentages
5. **🛒 Marketplace**: List for sale or direct licensing
6. **📄 Licensing**: Buyers license specific usage rights
7. **💸 Royalties**: Automatic distribution to creators

## 🛡️ Security Features

- **🔐 Access Control**: Owner-only functions for critical operations
- **✅ Input Validation**: Price, royalty, and parameter validation
- **⏰ Time-Based Licensing**: Automatic license expiration
- **🎯 Permission System**: Granular access control
- **💰 Secure Transfers**: Protected STX transfers with error handling

## 🧪 Testing

Run the test suite:
```bash
npm test
```

Test coverage includes:
- ✅ NFT minting and metadata
- 💰 Purchase and transfer flows  
- 📄 Licensing mechanisms
- 🔐 Access control validation
- 💸 Royalty distribution

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

- 📧 Email: support@datanft.exchange
- 💬 Discord: [Join our community](https://discord.gg/datanft)
- 📚 Documentation: [Full docs](https://docs.datanft.exchange)

---

<div align="center">

**🚀 Built with Stacks & Clarity | 🔒 Privacy-First | 💰 Creator-Owned**

[Website](https://datanft.exchange) • [Documentation](https://docs.datanft.exchange) • [Community](https://discord.gg/datanft)

</div>
