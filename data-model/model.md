# Commercial Bank Graph — Property Graph Data Model

## Overview

This model captures the Commercial Bank ecosystem: banked customers, unbanked entities discovered through transaction flows, their accounts, products, industries, and the payment transactions that connect them. It is designed for Neo4j Aura and mirrors the datasets described in the PoV planning document.

## Graph Model Diagram

```
                        ┌───────────┐
                   ┌───▶│  Industry  │
                   │    └───────────┘
              BELONGS_TO
                   │
              ┌────┴────┐  HAS_ACCOUNT   ┌─────────┐  SENT   ┌─────────────┐
              │ Customer │───────────────▶│ Account  │────────▶│ Transaction │
              └────┬────┘                 └─────────┘         └──────┬──────┘
                   │                           ▲                     │
              HOLDS_PRODUCT                    └─────────────────────┘
                   │                              RECEIVED_BY
              ┌────▼────┐
              │ Product  │
              └─────────┘

              ┌──────────┐  TRADES_WITH   ┌──────────┐
              │ Customer │╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶│ Customer │   (derived / aggregated)
              └──────────┘                └──────────┘

              ┌──────────┐ POTENTIAL_MATCH ┌──────────┐
              │ Customer │┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄▶│ Customer │  (entity resolution)
              │ (banked) │                 │(unbanked)│
              └──────────┘                 └──────────┘
```

### Node properties at a glance

```
┌──────────────────────────────────────────────────────────────────────┐
│  Customer                     │  Account           │  Transaction   │
│  ─────────                    │  ─────────         │  ─────────     │
│  customerId    STRING         │  accountId  STRING │  transactionId │
│  name          STRING         │  accountType       │  amount  FLOAT │
│  registrationNumber           │  openDate   DATE   │  currency      │
│  region        STRING         │  balance    FLOAT  │  date    DATE  │
│  segment       STRING         │                    │  channel       │
│  status   banked | unbanked   │                    │  reference     │
│  turnover      FLOAT          │                    │                │
│  riskScore     FLOAT          │                    │                │
│  pageRank*     FLOAT          │                    │                │
│  communityId*  INT            │                    │                │
│  betweenness*  FLOAT          │                    │                │
├───────────────────────────────┼────────────────────┼────────────────┤
│  Industry                     │  Product                            │
│  ─────────                    │  ─────────                          │
│  sicCode       STRING         │  productId  STRING                  │
│  name          STRING         │  name       STRING                  │
│  sector        STRING         │  pillar  lend|transact|invest|insure│
│                               │  monthlyFee FLOAT                   │
└──────────────────────────────────────────────────────────────────────┘

  * Written back by GDS algorithms (requires AuraDB Professional+)
```

### Relationship properties

```
TRADES_WITH  (Customer → Customer)
  ├── amount        FLOAT   Total traded amount in ZAR
  ├── txCount       INT     Number of transactions
  └── avgInterval   FLOAT   Average days between payments

HOLDS_PRODUCT  (Customer → Product)
  └── since         DATE    Date the product was taken up

All other relationships carry no properties.
```

## Node Descriptions

### Customer
Represents both **banked** and **unbanked** commercial entities. Banked customers are Commercial Bank clients; unbanked entities are counterparties discovered through transaction analysis that are not yet banked customers. The `status` property distinguishes the two.

| Property | Type | Description |
|---|---|---|
| customerId | STRING | Unique identifier |
| name | STRING | Business name |
| registrationNumber | STRING | Company registration number (null for unbanked) |
| region | STRING | Province / geographic region |
| segment | STRING | Commercial segment (SME, Mid-Corp, Large Corp) |
| status | STRING | `banked` or `unbanked` |
| turnover | FLOAT | Annual turnover in ZAR (null for unbanked) |
| riskScore | FLOAT | Internal risk score (null for unbanked) |
| pageRank | FLOAT | GDS PageRank score (written back by algorithm) |
| communityId | INT | GDS Louvain community ID (written back) |
| betweenness | FLOAT | GDS Betweenness Centrality score (written back) |

### Account
Bank account linked to a Customer.

| Property | Type | Description |
|---|---|---|
| accountId | STRING | Unique account number |
| accountType | STRING | cheque, savings, overdraft, loan |
| openDate | DATE | Date account was opened |
| balance | FLOAT | Current balance in ZAR |

### Transaction
Individual payment transaction flowing between accounts via various channels.

| Property | Type | Description |
|---|---|---|
| transactionId | STRING | Unique transaction reference |
| amount | FLOAT | Transaction amount in ZAR |
| currency | STRING | ISO currency code (ZAR, USD, EUR, GBP) |
| date | DATE | Transaction date |
| channel | STRING | `EFT`, `NAV`, `SOF`, or `SWIFT` |
| reference | STRING | Payment reference / description |

### Industry
SIC industry classification for commercial entities.

| Property | Type | Description |
|---|---|---|
| sicCode | STRING | Standard Industrial Classification code |
| name | STRING | Industry name |
| sector | STRING | High-level sector grouping |

### Product
bank product across the four pillars (lend, transact, invest, insure).

| Property | Type | Description |
|---|---|---|
| productId | STRING | Unique product identifier |
| name | STRING | Product name |
| pillar | STRING | `lend`, `transact`, `invest`, or `insure` |
| monthlyFee | FLOAT | Monthly fee in ZAR |

## Relationship Descriptions

| Relationship | From | To | Properties | Description |
|---|---|---|---|---|
| HAS_ACCOUNT | Customer | Account | since: DATE | Customer owns a bank account |
| BELONGS_TO | Customer | Industry | — | Customer operates in this industry |
| HOLDS_PRODUCT | Customer | Product | since: DATE | Customer holds this bank product |
| SENT | Account | Transaction | — | Account initiated the payment |
| RECEIVED_BY | Transaction | Account | — | Payment was received by this account |
| TRADES_WITH | Customer | Customer | amount: FLOAT, txCount: INT, avgInterval: FLOAT | Aggregated trading relationship between two entities |
| POTENTIAL_MATCH | Customer (banked) | Customer (unbanked) | confidence: FLOAT, nameSim: FLOAT, industrySim: FLOAT, regionSim: FLOAT, tradingSim: FLOAT | Entity resolution match — banked customer that likely corresponds to an unbanked entity |

## Design Rationale

1. **Single `Customer` label with `status` property** rather than separate `BankedCustomer`/`UnbankedEntity` labels — simplifies traversal queries and GDS projections while still allowing easy filtering.
2. **Transaction as a node** (not just a relationship) — preserves individual transaction detail needed for payment behaviour analysis, channel breakdowns, and temporal queries.
3. **TRADES_WITH as a derived relationship** — pre-aggregated edge between customers for efficient ecosystem traversal, community detection, and similarity algorithms. Created after data load via Cypher aggregation.
4. **GDS properties on Customer** (pageRank, communityId, betweenness) — written back by GDS algorithms so they're visible in Explore UI without re-running projections.
5. **POTENTIAL_MATCH for entity resolution** — links a banked customer to an unbanked entity that is likely the same real-world company. Uses a multi-signal composite score combining name similarity (Jaro-Winkler), industry match, region match, and trading partner overlap (Jaccard). Individual signal scores are stored on the relationship for explainability. Created by `06_entity_resolution.cypher`.
