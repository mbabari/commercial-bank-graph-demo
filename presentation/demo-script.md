# Commercial Bank Graph — Demo Script

## Setup Before the Demo

1. Open **Neo4j Aura Query UI** in a browser tab (https://console.neo4j.io → Open Query)
2. Open the **Dashboard** in another tab (http://localhost:3000)
3. Open **Neo4j Aura Explore** in a third tab
4. Pre-load the bookmark queries from `cypher/05_demo_bookmarks.cypher` (paste each into Aura and save as a Favourite/Bookmark)
5. Tested all queries run cleanly

---

## Act 1 — Set the Scene (3 min)

**Slides 1–4** (use presentation/slides.md)

Walk through the challenge, why graph, and the data model.

> "Commercial Bank processes millions of transactions between commercial entities. The relationships in that data — who pays whom, how often, through which channels — contain insights that traditional tabular analytics can't easily extract. Today we'll show you how a graph database answers your five key questions in real time."

---

## Act 2 — Dashboard Overview (2 min)

**Switch to: Dashboard → Overview page**

Show the audience:
1. **Key metrics at the top** — 800 customers, 1,116 accounts, 35K transactions, 14 products
2. **Transaction volume by channel** — bar chart showing EFT dominates, followed by NAV, SOF, SWIFT
3. **Top trading pairs** — the highest-volume customer-to-customer flows

> "This is the 10,000-foot view. 800 commercial entities, 35,000 transactions across 4 channels, all connected in a single graph. Let's drill into the specific questions you asked us to answer."

---

## Act 3 — Payment Behaviour (5 min)

### Dashboard Demo
1. Navigate to **Payment Behaviour** page
2. Select a customer from the dropdown (e.g. the first one)
3. Show the **Channel Breakdown** bar chart — "This customer transacts primarily via EFT and NAV"
4. Show the **Monthly Payment Trend** — "We can see payment volume peaking mid-year and levelling off"
5. Show the **Top 20 Trading Pairs** table — "Across the entire network, these are the most frequent payment relationships"

### Cypher Demo
Switch to **Aura Query UI**. Run these bookmarks:

**Bookmark: "1a — Top Trading Pairs"**
> "In a single Cypher query, we rank all customer pairs by how frequently they transact. The average interval tells us regularity — a pair trading every 3 days is very different from one trading every 60 days."

**Bookmark: "1b — Channel Breakdown"**
> "For any specific customer, we can break down their outgoing payments by channel, with averages, totals, and date ranges."

---

## Act 4 — Unbanked Identification (5 min)

### Dashboard Demo
1. Navigate to **Unbanked Targets** page
2. Point out the **3 metric cards** at the top — total volume, multi-payer targets, industries
3. Show the **Industry Distribution** horizontal bar chart — "Transport and Manufacturing have the highest unbanked volume"
4. Show the **Multi-Payer Targets** — "These entities are being paid by 3 or more of our customers — high-confidence conversion targets"
5. Show the **Top 25 table** — highlight the Priority badge (High / Medium / Low)

> "Every entity on this list is a warm lead. They're not random prospects — they already transact heavily with our customer base."

### Cypher Demo

**Bookmark: "2a — Top Unbanked by Volume"**
> "This query traverses the TRADES_WITH edges from banked to unbanked, aggregates inbound volume, and ranks them. Top entity has R___M flowing in from ___ banked customers."

**Bookmark: "2b — Multi-Payer Targets"**
> "Here we filter to unbanked entities receiving payments from 3 or more distinct banked customers. We even return the payer names — ready for the sales team."

### Explore UI Demo (if time permits)
1. In Explore, search for one of the top unbanked entities by name
2. Expand TRADES_WITH — show all the green (banked) nodes connecting to this one orange (unbanked) entity
3. > "Look — 8 of our customers all pay this entity. It's clearly an important part of their supply chain."

---

## Act 5 — Ecosystem Mapping (5 min)

### Dashboard Demo
1. Navigate to **Ecosystem Map** page
2. Select a customer — show the **visual network** with green (banked) and orange (unbanked) nodes arranged around the center
3. Show the **Direct Trading Partners** table — sorted by volume
4. Show **Ecosystem Leaders** — "These are the customers with the broadest 2-hop reach. Click one to explore their network."

> "This is a relationship manager's dream view. Before walking into a client meeting, they can see the customer's entire trading ecosystem — who they pay, who pays them, and whether those counterparties are our customers."

### Cypher Demo

**Bookmark: "3a — 2-Hop Ecosystem"**
Run in Query UI — this returns a **graph visualization** showing the full trading network.
> "Two hops out from a single customer and we can see their entire business ecosystem. Try doing this with a SQL JOIN."

**Bookmark: "3d — Ecosystem Size Ranking"**
> "Which of our customers have the broadest trading ecosystems? This is the network effect — customers with large ecosystems are strategically important."

---

## Act 6 — Product Cross-Sell (5 min)

### Dashboard Demo
1. Navigate to **Product Cross-Sell** page
2. Select a customer
3. Show **Current Products** panel — "This customer holds 3 products"
4. Show **Recommended Products** chart — "But their industry peers also hold Asset Finance and Fleet Insurance — those are the cross-sell opportunities, ranked by peer adoption"
5. Scroll to **Segment Penetration** table — "Across the board, we can see which products are under-adopted in each segment. Low penetration = opportunity."

> "This isn't guesswork. It's peer-based analysis. We're saying: businesses like yours, in your industry, in your segment, also hold these products."

### Cypher Demo

**Bookmark: "4b — Peer Product Recommendations"**
> "For a specific customer, find products that their industry peers hold but they don't. Simple, powerful, and it runs in 20ms."

**Bookmark: "4c — Segment Gap Analysis"**
> "At the portfolio level, which products are under-penetrated in which segments? This drives strategic product campaigns."

---

## Act 7 — Credit & Collateral Scoring (5 min)

### Dashboard Demo
1. Navigate to **Credit Scoring** page
2. Show the **Scatter Plot** — "X-axis is number of distinct payers, Y-axis is total inflow, bubble size is channel diversity. Top-right means diversified, high-volume — low risk."
3. Show **Revenue Concentration Risk** — "This table shows how dependent each customer is on their single largest payer. Above 50% is a red flag."
4. Show **Payment Diversity Scores** — "We automatically grade customers as LOW RISK, MEDIUM RISK, or HIGHER RISK based on payer count and channel diversity"
5. Show **Stability Scores** — "Customers with regular, consistent payment intervals are graded HIGHLY STABLE"

> "Traditional credit scoring looks at balance sheets. Graph-based scoring looks at the reality — who actually pays this business, how often, through how many channels, and how concentrated that income is."

### Cypher Demo

**Bookmark: "5a — Collateral Grading"**
> "One query, real-time. It calculates payer diversity, channel diversity, and assigns a collateral grade."

**Bookmark: "5b — Concentration Risk"**
> "For each customer, what % of their inbound revenue comes from their single largest payer? If it's 70%, that's a concentration risk that should factor into credit decisions."

---

## Act 8 — Entity Resolution (7 min)

### Set Up (Slides)

Use the **Entity Resolution slides** (Use Case 6) to frame the problem before showing the demo.

> "Before we close, there's one more capability that's uniquely suited to graph — entity resolution. The fundamental problem: the same real-world company can appear in your data under different names, in different systems, with different identifiers. Traditional ER tools compare names and addresses. Graph adds an entirely new dimension."

**Walk through the cross-industry slide:** FSI/Fraud, Healthcare/NHS, Public Sector.

> "In FSI, it's 'who is the ultimate beneficial owner behind these shell companies?' In healthcare, it's 'is this the same patient across the GP, hospital, and pharmacy — and getting it wrong could be fatal.' In government, it's one citizen with records across tax, welfare, and immigration. The common thread: uncertain identity across fragmented systems. Graph is the only technology that can use the *structure of the network* — shared connections, trading patterns, community membership — as evidence for identity."

### Cypher Demo

Switch to **Aura Query UI**. Run these bookmarks:

**Bookmark: "6a — Top Entity Resolution Matches"**
> "Our pipeline scored every unbanked-to-banked pair using four signals: name similarity, industry match, region match, and — this is the graph-specific one — overlap in trading partners. Here are the top matches ranked by confidence."

Point out the individual signal columns: `nameSimilarity`, `sameIndustry`, `sameRegion`, `tradingOverlap`.

> "Every match is explainable. We can see *why* the system thinks these are the same entity. The name for 'Sandton Mfg' is clearly an abbreviation of 'Sandton Manufacturing' — that's the name signal. But look at the trading overlap column — they also share counterparties. That's structural evidence that a traditional ER tool would never see."

**Bookmark: "6b — High-Confidence Matches"**
> "Filtering to confidence >= 0.70, these are candidates for automated merging. Below that threshold, they go to a manual review queue."

**Bookmark: "6d — Hidden Trading Volume"**
> "Here's the business impact. These unbanked entities are generating significant trading volume that isn't being attributed to the correct banked customer. This is revenue visibility — and potentially risk exposure — that was completely invisible before."

### Explore UI Demo

**Bookmark: "6c — Graph View of a Match"** (or run the Scene 8 Cypher in Explore)

1. Show the matched pair: green (banked) and orange (unbanked) nodes connected by a `POTENTIAL_MATCH` edge
2. Point out the **shared trading partners** — nodes connected to both entities
3. Click the `POTENTIAL_MATCH` edge to show the signal decomposition in the property panel

> "This is the moment where graph entity resolution clicks. Look at the centre of this visualisation — those are the counterparties that *both* entities trade with. Traditional ER sees two records with similar names. Graph ER sees two records with similar names, in the same industry, in the same region, *AND trading with the same 5 companies*. That's evidence you cannot get from any other technology."

### The Bigger Picture

> "What we've shown here with the bank is a proof point. The same pipeline — attribute signals plus graph-structural signals, with explainable confidence scores — applies to every domain where identity is uncertain. Financial crime, patient matching, citizen identity. The graph doesn't just find matches; it provides auditable *evidence* for why they match. In regulated industries, that's not optional — it's required."

---

## Act 9 — Close (2 min)

Return to **slides** — Summary slide and Next Steps.

> "We've shown that a single graph model answers all six questions — payment behaviour, unbanked identification, entity resolution, ecosystem mapping, cross-sell, and credit scoring. Every query runs in real time. The dashboard is live. And Neo4j Explore lets any business user navigate the graph without writing code."

> "Entity resolution in particular shows a capability that goes beyond a single institution — graph-enhanced identity matching is a platform capability applicable across FSI, healthcare, and the public sector."

> "The next step is connecting this to real production transaction data and putting it in front of relationship managers."

---

## Timing Guide

| Section | Minutes | Running Total |
|---------|---------|--------------|
| Slides (scene setting) | 3 | 3 |
| Dashboard overview | 2 | 5 |
| Payment behaviour | 5 | 10 |
| Unbanked identification | 5 | 15 |
| Ecosystem mapping | 5 | 20 |
| Product cross-sell | 5 | 25 |
| Credit scoring | 5 | 30 |
| Entity resolution | 7 | 37 |
| Close + Q&A | 5 | 42 |

**Total: ~42 minutes** (adjust by skipping Explore UI sections or shortening earlier acts if short on time)
