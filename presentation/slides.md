# Commercial Bank Graph
## Neo4j Aura — Proof of Value

**Commercial Bank**

*Unlocking the hidden value in your commercial payment ecosystem*

---

# The Challenge

Commercial Bank sits on **massive transaction data** — millions of EFT, NAV, SOF, and SWIFT payments flowing between commercial entities every month.

**But the value is trapped in tables.**

- Who are the most important entities in the network — and are they even our customers?
- Which unbanked entities receive significant payment volume from our clients?
- What does a customer's full trading ecosystem look like?
- What products should we recommend based on what similar businesses hold?
- Can we score creditworthiness using payment behaviour, not just financial statements?

> **These are graph questions. They need a graph database.**

---

# Why Graph?

```
Traditional (SQL)                          Graph (Neo4j)
─────────────────                          ─────────────
10+ table joins                            Single traversal
Minutes to compute                         Milliseconds
Fragile ETL pipelines                      Always-current data
Hard to explore                            Visual, interactive
Static reports                             Real-time discovery
```

**Neo4j stores relationships as first-class citizens.** Instead of joining tables to reconstruct connections, the graph already has them.

A query like *"find all unbanked entities receiving payments from 3+ of our customers"* is a natural graph pattern — and it runs in milliseconds.

---

# What We Built

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Graph Database** | Neo4j Aura | Store & traverse the commercial ecosystem |
| **Data** | 800 entities, 35K transactions, 14 products | Synthetic dataset modelling Commercial Bank |
| **Cypher Queries** | 13 business queries across 5 user stories | Direct answers to the PoV questions |
| **Dashboard** | Next.js + Recharts | Interactive frontend for business users |
| **Explore UI** | Neo4j Aura Explore | Visual graph exploration for analysts |

---

# The Data Model

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
    │ Customer │╌╌╌╌╌╌╌╌╌╌╌╌╌╌▶│ Customer │   (aggregated)
    └──────────┘                └──────────┘
```

- **800 commercial entities** (500 banked banked customers + 300 unbanked)
- **1,116 accounts** across cheque, savings, overdraft, loan
- **35,000 transactions** across EFT, NAV, SOF, SWIFT channels
- **33,575 TRADES_WITH relationships** — aggregated customer-to-customer edges
- **14 products** across lend, transact, invest, insure

---

# Use Case 1 — Payment Behaviour

> *"As a data scientist I want to gain insights into client payment behaviour and frequency to provide valuable insights into working capital requirements."*

### What the graph reveals:
- **Top 20 trading pairs** by transaction frequency
- **Channel breakdown** per customer (EFT vs NAV vs SOF vs SWIFT)
- **Monthly payment trends** — is a customer's volume growing or declining?
- **Average payment intervals** — how regular are their payments?

### Demo:
1. **Dashboard** → Payment Behaviour page → select a customer
2. **Cypher** → Query 1a: top trading pairs ranked by frequency
3. **Cypher** → Query 1b: channel breakdown for a specific customer

> **Business value:** Working capital insights, short-term facility sizing, early warning on declining payment activity.

---

# Use Case 2 — Unbanked Client Identification

> *"As a data scientist I want to identify unbanked clients for potential sales opportunities."*

### What the graph reveals:
- **Top 25 unbanked entities** by inbound payment volume from banked customers
- **Multi-payer targets** — unbanked entities paid by 3+ distinct banked customers (high-confidence conversion)
- **Industry distribution** — which sectors have the most unbanked opportunity?

### Demo:
1. **Dashboard** → Unbanked Targets page → see priority-ranked conversion list
2. **Cypher** → Query 2a: top unbanked by inbound volume
3. **Cypher** → Query 2b: multi-payer targets with payer names
4. **Explore UI** → Expand an unbanked entity to see all its banked connections

> **Business value:** Every entity on this list is a warm lead — they already transact heavily with banked customers. The sales team gets a prioritised list, not a cold database.

---

# Use Case 3 — Ecosystem Mapping

> *"As a data scientist I want to understand the ecosystem of our customers for strategic sales drives."*

### What the graph reveals:
- **2-hop trading network** for any customer — who they trade with, and who *those* entities trade with
- **Shared counterparties** between two customers — where ecosystems overlap
- **Industry ecosystem view** — all trading within a sector (e.g. Manufacturing)
- **Ecosystem size ranking** — which customers have the broadest reach?

### Demo:
1. **Dashboard** → Ecosystem Map → visual network for a selected customer
2. **Cypher** → Query 3a: full 2-hop ecosystem (graph visualization in Query UI)
3. **Explore UI** → Right-click → Expand TRADES_WITH to navigate interactively

> **Business value:** Relationship managers can see the full picture before a client meeting. Strategic sales can identify cluster-based campaigns instead of individual targeting.

---

# Use Case 4 — Product Cross-Sell

> *"As a data scientist I want to improve our fit-for-purpose product offering."*

### What the graph reveals:
- **Peer-based recommendations** — products popular with industry peers that a customer doesn't hold
- **Segment penetration gaps** — which products are under-adopted in SME vs Mid-Corp vs Large Corp?
- **Product portfolio comparison** — side-by-side for any two customers

### Demo:
1. **Dashboard** → Product Cross-Sell → see current products vs. peer recommendations
2. **Cypher** → Query 4b: products popular in the same industry but not held
3. **Cypher** → Query 4c: segment-level penetration analysis

> **Business value:** Data-driven product recommendations. Instead of generic campaigns, each customer gets a tailored recommendation based on what similar businesses actually use.

---

# Use Case 5 — Credit & Collateral Scoring

> *"As a data scientist I want to enable collateralised scoring on platform."*

### What the graph reveals:
- **Payment diversity score** — number of distinct payers, channel diversity, total inflow → collateral grade
- **Revenue concentration risk** — what % of income comes from a single payer?
- **Payment stability** — standard deviation of payment intervals → stability grade

### Demo:
1. **Dashboard** → Credit Scoring → diversity scores with collateral grades
2. **Dashboard** → Concentration risk table showing single-payer dependency
3. **Cypher** → Query 5a: full diversity scoring with LOW/MEDIUM/HIGHER RISK grades
4. **Cypher** → Query 5b: concentration risk ranked by % from largest payer

> **Business value:** Graph-derived credit signals that complement traditional scoring. A customer receiving regular payments from 15+ diverse counterparties across 4 channels is fundamentally different from one dependent on a single payer — even if their turnover is the same.

---

# Use Case 6 — Entity Resolution

> *"The same company appears in our data under different names, different systems, different identifiers. How do we know it's them?"*

### The fundamental challenge: What *is* the entity?

Entity resolution isn't just deduplication — it's the problem of **defining identity** when records are uncertain, incomplete, and spread across systems.

```
                Traditional ER                  Graph-Enhanced ER
                ──────────────                  ─────────────────
Signals:        Name, address, ID number        Name, address, ID number
                                                + shared counterparties
                                                + trading patterns
                                                + community membership
                                                + network topology

Approach:       Pairwise record comparison      Multi-signal scoring
                Linear O(n²) blocking           Graph-native traversal
                Static rules                    Structural + attribute signals

Explainability: "Names matched at 87%"          "Names match at 87%, same industry,
                                                 same region, AND they trade with
                                                 5 of the same counterparties"
```

### Why this matters beyond a single institution

| Industry | The Entity Problem | The Risk of Getting It Wrong |
|----------|--------------------|------------------------------|
| **FSI & Fraud** | Who is the ultimate beneficial owner? Shell companies, nominee directors, layered structures hide the real person | Regulatory fines, undetected money laundering, sanctions breaches |
| **Healthcare / NHS** | The same patient across GP, hospital, lab, pharmacy — often with no single reliable ID | Wrong treatment, drug interactions, misdiagnosis — **patient death** |
| **Public Sector** | One citizen, dozens of records across tax, welfare, licensing, education, immigration | Fraud, duplicated benefits, missed safeguarding referrals |

### What graph brings to the table

**Attribute-based signals** (name similarity, address, DOB) are necessary but **not sufficient**. Two records could have different names and still be the same entity — or identical names and be different people.

**Graph adds structural signals:**
- **Shared relationships** — two entities that trade with the same 5 counterparties are likely the same company
- **Network position** — same community, same PageRank neighbourhood
- **Temporal patterns** — transactions stop for entity A exactly when they start for entity B
- **Relationship topology** — the *shape* of an entity's network is a fingerprint

> **Graph doesn't replace traditional ER — it makes it dramatically more accurate by adding dimensions that tabular systems cannot see.**

### Demo: The Proof

Our pipeline uses **4 weighted signals** to find unbanked entities that are actually existing banked customers:

| Signal | Weight | Type |
|--------|--------|------|
| Name similarity (Jaro-Winkler) | 0.40 | Attribute |
| Same SIC industry code | 0.20 | Attribute |
| Same region / province | 0.15 | Attribute |
| Shared trading partners (Jaccard) | 0.25 | **Graph-structural** |

Results are written as `POTENTIAL_MATCH` relationships with full signal decomposition — every match is **explainable**.

---

# Entity Resolution — The Bigger Picture

### This is not an institution-specific feature. It's a **platform capability**.

```
  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
  │   FSI / AML  │     │  Healthcare  │     │ Public Sector│
  │              │     │              │     │              │
  │  Shell co    │     │  Patient A   │     │  Citizen X   │
  │  Nominee dir │     │  (GP record) │     │  (tax record)│
  │  Beneficial  │     │  Patient A'  │     │  Citizen X'  │
  │  owner?      │     │  (hospital)  │     │  (welfare)   │
  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘
         │                    │                     │
         ▼                    ▼                     ▼
  ┌──────────────────────────────────────────────────────┐
  │              Neo4j Entity Resolution                  │
  │                                                      │
  │  Attribute signals  +  Graph-structural signals      │
  │  (name, ID, address)   (shared connections,          │
  │                         network topology,             │
  │                         transaction patterns)         │
  │                                                      │
  │  → POTENTIAL_MATCH with confidence + explainability   │
  └──────────────────────────────────────────────────────┘
```

**Key insight:** The graph doesn't just *find* matches — it provides **evidence** for why they match, which is essential for regulated industries where decisions must be auditable.

---

# The Technology Advantage

| Capability | What Neo4j Delivers |
|------------|-------------------|
| **Real-time traversal** | No batch jobs — queries run in milliseconds against live data |
| **Pattern matching** | Cypher finds complex multi-hop patterns that SQL cannot express |
| **Entity resolution** | Multi-signal matching using both attribute and graph-structural signals |
| **Visual exploration** | Explore UI lets any business user navigate the graph interactively |
| **Graph algorithms** | PageRank, community detection, similarity — all built in with GDS |
| **Scalability** | Aura Professional scales to billions of nodes and relationships |
| **Integration** | REST/Bolt API, MCP server for AI integration, dashboard-ready |

---

# What's Next

### Immediate (PoV → Pilot)
- Connect to **real production transaction data** (replace synthetic)
- Onboard 2–3 relationship managers for feedback
- Enable **GDS algorithms** on Aura Professional (PageRank, community detection)

### Near-term (Pilot → Production)
- Integrate with the bank's existing **CRM and data warehouse**
- Build automated **unbanked lead scoring pipeline**
- Scale entity resolution to **real customer base** — replace planted duplicates with production data
- Add **fraud detection patterns** (circular payments, unusual flows)
- Deploy dashboard to the **RM and Sales teams**

### Future
- **AI-powered insights** — natural language queries via MCP + LLM integration
- **Cross-system entity resolution** — extend ER beyond payments to CRM, KYC, and external data sources
- **Real-time streaming** — ingest transactions as they happen
- **Regulatory reporting** — AML/KYC network analysis
- **Platform ER capability** — apply the same graph-enhanced resolution approach to healthcare, public sector, and fraud

---

# Summary

We demonstrated that **Neo4j answers all six PoV questions** — in real time, with a single data model:

| Question | ✓ Answered |
|----------|-----------|
| Payment behaviour & frequency | ✓ Channel breakdown, trends, intervals |
| Unbanked client identification | ✓ Prioritised conversion targets with multi-payer confidence |
| Entity resolution | ✓ Multi-signal matching with graph-structural evidence |
| Ecosystem mapping | ✓ Multi-hop traversal, shared counterparties, industry clusters |
| Product cross-sell | ✓ Peer-based recommendations, segment gap analysis |
| Credit / collateral scoring | ✓ Diversity, concentration, stability grades |

> **The graph is the business.**
> Every relationship between your customers, their counterparties, and their products is a data point waiting to drive revenue, reduce risk, and deepen relationships.
>
> Entity resolution shows this uniquely — **only a graph can use the shape of the network as evidence for identity**. This applies at a commercial bank, and it applies everywhere identity is uncertain: financial crime, healthcare, government.

---

# Thank You

**Let's explore the live demo.**

- **Dashboard:** http://localhost:3000
- **Neo4j Aura:** https://console.neo4j.io
- **Repository:** github.com/YOUR_GITHUB_ORG/commercial-bank-graph-demo

*Questions?*
