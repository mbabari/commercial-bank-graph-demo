# Entity Resolution with Neo4j — Cross-Industry Positioning

## The Core Problem: What *Is* the Entity?

Entity resolution is often reduced to "deduplication" — finding duplicate records and merging them. But the real problem is deeper: **defining what constitutes an entity when identity is uncertain, fragmented, and spread across systems**.

A person, a company, an asset — these are not rows in a table. They are patterns of relationships, behaviours, and attributes that exist across multiple data sources, each with their own schema, their own identifiers, and their own version of the truth.

Traditional ER approaches compare **attributes** (name, address, date of birth, registration number) and score similarity. This works when the data is clean and identifiers are reliable. It fails when they aren't — which is most of the time.

**Graph-enhanced ER adds a dimension that tabular systems cannot access: the structure of the network.** Two records might have different names but trade with the same counterparties. Two patients might have different addresses but visit the same GP, take the same medications, and appear in the same household. Two citizens might have slightly different ID numbers but share the same dependents, the same employer, and the same residence.

The graph doesn't just find matches — it provides **structural evidence** for identity.

---

## Industry Perspectives

### Financial Services & Fraud

**The entity problem:** Who is the ultimate beneficial owner?

Financial crime depends on obscuring identity. Shell companies, nominee directors, layered corporate structures, and trust arrangements are designed to make it impossible to answer the question: "who really controls this money?"

**Traditional ER fails because:**
- Shell companies have clean, unique registration numbers — they're not "duplicates" in the attribute sense
- Nominee directors appear as different people in different jurisdictions
- The same person can operate through dozens of legal entities with no shared attributes

**Graph adds:**
- **Shared directorship patterns** — two companies with the same set of directors are likely controlled by the same person
- **Transaction flow topology** — money flowing in circular patterns through entities that share a controller
- **Network proximity** — entities that appear in the same community/cluster despite having no shared attributes
- **Temporal sequencing** — entity A ceases activity exactly when entity B becomes active, suggesting a "phoenix" operation

**The question shifts from** "do these records have the same name?" **to** "do these entities behave as if they are the same actor?"

**Risk of getting it wrong:** Regulatory fines (up to 10% of global turnover under EU AML directives), sanctions breaches, enabling money laundering and terrorist financing.

---

### Healthcare & Research / NHS

**The entity problem:** Is this the same patient?

A single patient generates records across GPs, hospitals, labs, pharmacies, emergency departments, mental health services, social care, and research databases. In the UK, the NHS number provides a common identifier — but it's missing, incorrect, or duplicated more often than most people assume.

Internationally, the problem is far worse. Many countries have no universal health identifier. Patients present at emergency departments unconscious, confused, or without documentation.

**Traditional ER fails because:**
- Names are recorded differently across systems (married vs maiden, transliteration of non-English names, nicknames)
- Addresses change, dates of birth are entered incorrectly, and ID numbers are reused or miskeyed
- In emergency settings, there is no time for manual verification
- **False positives are potentially fatal** — merging two different patients means drug allergies, blood types, and treatment histories are combined

**Graph adds:**
- **Shared practitioner/facility patterns** — two records that share the same GP, the same consultant, and the same pharmacy are likely the same patient
- **Household/family network** — records linked to the same emergency contact, same address, same dependents
- **Care pathway topology** — the sequence and timing of referrals, admissions, and prescriptions forms a pattern unique to each patient
- **Medication network** — the combination of prescriptions creates a medication "fingerprint" that is extremely specific

**The question shifts from** "do these records have the same NHS number?" **to** "do these records describe the same care journey?"

**Risk of getting it wrong:**
- **False positive (incorrect merge):** Patient receives wrong medication, wrong blood type, or treatment contraindicated by a condition they don't have → **patient death**
- **False negative (missed merge):** Fragmented record means clinicians don't see the full picture → delayed diagnosis, repeated tests, drug interactions

**Graph provides confidence scores and evidence decomposition** so that clinicians can make informed decisions about uncertain matches, rather than relying on binary yes/no matching rules.

---

### Public Sector & Government

**The entity problem:** One citizen, dozens of records, no single source of truth.

A citizen interacts with government through tax (HMRC/SARS), welfare (DWP/SASSA), healthcare (NHS/DoH), education, immigration, licensing, criminal justice, and local councils. Each system has its own identifier, its own data quality standards, and its own version of the citizen's details.

**Traditional ER fails because:**
- No single identifier is used consistently across all systems
- Data is entered by thousands of different clerks with varying accuracy
- Citizens change names (marriage, deed poll), addresses (frequently), and even legal identity (immigration status)
- Privacy regulations limit what data can be shared between departments
- **Scale is enormous** — tens of millions of citizens × dozens of systems = billions of potential comparisons

**Graph adds:**
- **Shared household and family structure** — records linked to the same spouse, children, or dependents
- **Shared address history** — not just "same current address" but the same *sequence* of addresses over time
- **Shared institutional relationships** — same employer, same school, same local authority
- **Benefit/tax network** — the combination of benefits claimed and taxes paid creates a fiscal fingerprint
- **Temporal consistency** — records that describe the same life events (birth of a child, change of address) at the same time

**The question shifts from** "do these records have the same ID number?" **to** "do these records describe the same life?"

**Risk of getting it wrong:**
- **False positive:** Two citizens merged → duplicate benefit payments, incorrect tax assessments, wrongful criminal records
- **False negative:** Fragmented identity → failed safeguarding (child protection cases where records weren't linked), benefit fraud undetected, immigration violations missed

---

## Why Graph Beats Traditional ER

### The Fundamental Limitation of Tabular ER

Traditional ER tools (Informatica MDM, IBM InfoSphere, Reltio, etc.) operate on **pairwise record comparison**:

1. **Blocking:** Reduce the n² comparison space by grouping records with shared attributes (same postcode, same first name initial)
2. **Comparison:** Score each pair on attribute similarity (Jaro-Winkler on name, edit distance on address, exact match on DOB)
3. **Classification:** Apply thresholds or ML models to classify each pair as match / non-match / possible match
4. **Merging:** Create a "golden record" from matched pairs

This is effective for **attribute-rich, well-structured data**. It fails when:

- Attributes are sparse or unreliable
- The same attribute values appear on genuinely different entities
- The identity signal is in the *relationships*, not the attributes

### What Graph Adds

| Dimension | Tabular ER | Graph ER |
|-----------|-----------|---------|
| **Signals** | Attributes only | Attributes + relationships + topology |
| **Blocking** | Attribute-based (postcode, name initial) | Graph-based (shared neighbours, community) |
| **Evidence** | "87% name match" | "87% name match + same industry + same region + 5 shared counterparties" |
| **Transitivity** | Pairwise only (A=B, B=C, but no inference about A=C) | Natural transitivity via graph traversal |
| **Scale** | O(n²) worst case, O(n·b) with blocking | Graph traversal is naturally bounded by connectivity |
| **Explainability** | Score decomposition on attributes | Full path-based evidence including relationships |
| **Adaptability** | New attributes require schema changes | New relationship types are just new edges |

### The Structural Fingerprint

The key insight: **an entity's network neighbourhood is a fingerprint**.

Two companies that trade with the same 5 counterparties, in the same industry, in the same region, with the same payment patterns — they are almost certainly the same company, even if their names look nothing alike.

Two patients that visit the same GP, take the same medications, live at the same address, and have the same emergency contact — they are almost certainly the same patient, even if their names are spelled differently in two systems.

**This structural fingerprint is invisible to any system that doesn't store and traverse relationships as first-class citizens.**

---

## The Neo4j ER Architecture

```
  ┌──────────────────────────────────────────────────────────┐
  │                    Source Systems                          │
  │  CRM  │  Core Banking  │  EHR  │  Tax  │  Welfare  │ ... │
  └───┬───┴───────┬────────┴───┬───┴───┬───┴─────┬─────┴─────┘
      │           │            │       │         │
      ▼           ▼            ▼       ▼         ▼
  ┌──────────────────────────────────────────────────────────┐
  │              Neo4j Property Graph                         │
  │                                                          │
  │  Nodes: entities from each source system                 │
  │  Relationships: transactions, referrals, registrations   │
  │  Properties: attributes from source records              │
  └──────────────────────────────────────────────────────────┘
      │
      ▼
  ┌──────────────────────────────────────────────────────────┐
  │          Entity Resolution Pipeline                       │
  │                                                          │
  │  1. Blocking    — fulltext index + graph neighbourhood   │
  │  2. Scoring     — attribute signals + structural signals │
  │  3. Thresholds  — auto-merge / manual-review / reject    │
  │  4. Output      — POTENTIAL_MATCH relationships with     │
  │                   confidence scores + signal breakdown    │
  └──────────────────────────────────────────────────────────┘
      │
      ▼
  ┌──────────────────────────────────────────────────────────┐
  │              Downstream Consumption                       │
  │                                                          │
  │  - Golden record / master data                           │
  │  - Fraud alerts (UBO resolution)                         │
  │  - Clinical safety (patient matching)                    │
  │  - Audit trail (why was this match made?)                │
  │  - Continuous re-scoring as new data arrives             │
  └──────────────────────────────────────────────────────────┘
```

---

## Demo: Proof of Concept

The Commercial Bank Graph demo implements a complete ER pipeline on synthetic data:

| Component | Implementation |
|-----------|---------------|
| **Source data** | 500 banked customers + 300 unbanked entities (40 planted near-duplicates) |
| **Blocking** | Lucene fulltext index on `Customer.name` with fuzzy search |
| **Attribute signals** | Jaro-Winkler name similarity (0.40), SIC code match (0.20), region match (0.15) |
| **Structural signal** | Jaccard overlap on TRADES_WITH neighbours (0.25) |
| **Output** | `POTENTIAL_MATCH` relationships with composite confidence + per-signal scores |
| **Validation** | Ground truth file (`er_ground_truth.csv`) with 40 known pairs |

### Running the Demo

```
1. Load data:     cypher/01_schema.cypher → cypher/02_load_data.cypher
2. Build graph:   TRADES_WITH relationships (part of 02_load_data.cypher)
3. Run ER:        cypher/06_entity_resolution.cypher
4. Explore:       cypher/05_demo_bookmarks.cypher (bookmarks 6a–6e)
5. Visualise:     Explore UI Scene 8
```

### Key Talking Points for the Demo

1. **"Part of the problem is defining what the entity is"** — Start here. The entity isn't a row; it's a pattern of relationships and behaviours.

2. **"Traditional ER matches on attributes. Graph ER matches on structure."** — Show a match where name similarity alone wouldn't be conclusive, but shared trading partners seal it.

3. **"Every match is explainable"** — Click on the POTENTIAL_MATCH edge and walk through each signal. This is critical for regulated industries.

4. **"This applies everywhere identity is uncertain"** — FSI (beneficial ownership), healthcare (patient safety), government (citizen identity). The technology is the same; the domain model changes.

5. **"The risk of getting it wrong varies by domain"** — In FSI, it's fines. In healthcare, it's death. In government, it's fraud or failed safeguarding. The confidence thresholds should reflect this.
