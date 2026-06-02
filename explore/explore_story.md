# Commercial Bank Graph — Explore UI Walkthrough

## Persona

**Thandi Nkosi**, Sales Analyst at Commercial Bank. Thandi's goal is to find high-value unbanked entities in the payment network that are strong candidates for bank onboarding, and to identify cross-sell opportunities within existing customer ecosystems.

---

## Prerequisites

Before starting, ensure:
1. All data has been loaded (run `01_schema.cypher` then `02_load_data.cypher`).
2. GDS algorithms have been run (`04_gds_algorithms.cypher`) so that `pageRank`, `communityId`, and `betweenness` properties are present on Customer nodes.
3. Open **Neo4j Aura** and switch to the **Explore** view.

---

## Scene 1 — Start from a Key Customer

**Goal:** Orient ourselves around a high-value banked customer.

### Steps

1. In the **Search bar** at the top of Explore, type the customer name — for example, search for a Large Corp customer in Gauteng.
   - Alternatively use a Cypher search:
     ```
     MATCH (c:Customer {status: 'banked', segment: 'Large Corp', region: 'Gauteng'})
     RETURN c LIMIT 5
     ```
2. Click on one of the returned Customer nodes to add it to the canvas.
3. **Inspect the node properties** in the right-hand panel: name, segment, turnover, riskScore, region.

> **Talking point:** "This is one of our large corporate customers in Gauteng. Let's see who they trade with."

---

## Scene 2 — Expand the Direct Trading Network

**Goal:** Reveal all entities this customer trades with.

### Steps

1. **Right-click** the Customer node on the canvas.
2. Select **Expand** → **TRADES_WITH** (both directions).
3. The canvas now shows all direct counterparties — both banked (banked customers) and unbanked (unbanked counterparties).

### Visual Setup

4. Open the **Style** panel (paintbrush icon).
5. Set **node colour** by the `status` property:
   - `banked` → green
   - `unbanked` → orange
6. Set **node size** by `pageRank` (higher PageRank = larger node).
7. Set **relationship thickness** by `amount` on TRADES_WITH.

> **Talking point:** "Green nodes are our customers; orange nodes are entities we don't bank. Notice the large orange node — that entity receives significant payment volume."

*[Screenshot placeholder: Canvas showing central customer with green and orange satellite nodes, relationship lines of varying thickness]*


---

## Scene 3 — Expand the Unbanked Entity's Full Ecosystem

**Goal:** Understand the full trading network of the unbanked target.

### Steps

1. **Right-click** the unbanked entity node.
2. Select **Expand** → **TRADES_WITH** (both directions).
3. The canvas now reveals all counterparties of this unbanked entity.
4. Notice how **multiple green (banked) nodes** connect to this single orange entity.

### Additional Context

5. **Right-click** the unbanked entity → **Expand** → **BELONGS_TO** to see its Industry.
6. Select several of the connected banked customers → **Expand** → **HOLDS_PRODUCT** to see which bank products they hold.

> **Talking point:** "Sandton Logistics trades with 8 of our banked customers and 3 other unbanked entities. It operates in the Transport sector. Our banked counterparties in this cluster hold Cheque Accounts, Overdrafts, and Fleet Insurance — these are the products we'd lead with when onboarding this prospect."

*[Screenshot placeholder: Expanded view showing unbanked entity at centre, connected to multiple banked customers and their products]*

---

## Scene 4 — Cross-Sell Opportunity within the Cluster

**Goal:** Identify products that peer customers hold but this customer's cluster does not.

### Steps

1. Select the **original customer node** from Scene 1.
2. **Right-click** → **Expand** → **HOLDS_PRODUCT**.
3. Now select one of their **industry peers** (another banked customer in the same BELONGS_TO industry).
4. **Expand** that peer's products as well.
5. **Compare** the product sets visually on the canvas.

> **Talking point:** "Our target customer holds a Cheque Account and an Overdraft, but their peers in Manufacturing also hold Asset Finance and Commercial Property Insurance. That's a clear cross-sell opportunity worth bringing to the relationship manager."

*[Screenshot placeholder: Two customer nodes with their product nodes expanded, showing product overlap and gaps]*

---

## Scene 5 — Community Structure and Industry Clusters

**Goal:** Use GDS-enriched properties to visualise the community landscape.

### Steps

1. Clear the canvas or start a new scene.
2. Run a Cypher search in Explore to pull a community:
   ```
   MATCH (c:Customer)
   WHERE c.communityId = 3
   RETURN c LIMIT 50
   ```
3. Expand all TRADES_WITH relationships within this group.
4. **Colour** nodes by `communityId` to see if sub-clusters emerge.
5. **Size** nodes by `betweenness` — the largest nodes are brokers connecting different parts of the ecosystem.

### Highlight the Broker

6. Click the node with the highest betweenness centrality.
7. Inspect its properties: this entity bridges multiple trading communities.

> **Talking point:** "Community 3 contains 42 entities — mostly in Manufacturing and Transport. The node with the highest betweenness is *Midrand Engineering*, which trades with companies in both communities 3 and 7. If Midrand Engineering churns, it would fragment connectivity between these clusters. This insight is valuable for credit risk and relationship management."

*[Screenshot placeholder: Community graph with nodes coloured by communityId, sized by betweenness, showing a clear broker node]*

---

## Scene 6 — Entity Resolution: Finding Hidden Duplicates

**Goal:** Demonstrate how graph-based entity resolution identifies unbanked entities that are actually existing banked customers operating under a different name.

### Prerequisites

Run `cypher/06_entity_resolution.cypher` to create `POTENTIAL_MATCH` relationships.

### Steps

1. Run a Cypher search in Explore to pull the top entity resolution matches:
   ```
   MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
   WHERE m.confidence >= 0.65
   WITH b, u, m ORDER BY m.confidence DESC LIMIT 5
   OPTIONAL MATCH (b)-[:TRADES_WITH]-(bp:Customer)
   OPTIONAL MATCH (u)-[:TRADES_WITH]-(up:Customer)
   RETURN b, u, m, bp, up
   ```
2. **Colour** nodes by `status` (green = banked, orange = unbanked).
3. Use a **distinct style** for `POTENTIAL_MATCH` edges (e.g. red, dashed) to distinguish them from `TRADES_WITH`.
4. Click the `POTENTIAL_MATCH` edge to inspect individual signals in the property panel: `nameSim`, `industrySim`, `regionSim`, `tradingSim`, and the composite `confidence`.

### Highlight the Overlap

5. Note how the banked customer and the matched unbanked entity share trading partners — the overlapping nodes in the centre of the graph.
6. **Right-click** both nodes → **Expand** → **BELONGS_TO** to confirm they belong to the same industry.

> **Talking point:** "Entity resolution found that this unbanked entity — *Nelspruit Eng* — is likely the same company as our banked customer *Nelspruit Engineering*. The names are similar, they operate in the same industry and region, and — here's where the graph shines — they trade with many of the same counterparties. Traditional ER can match on name and attributes, but only a graph can detect the shared trading pattern. The confidence score tells us this is a 78% match."

*[Screenshot placeholder: Matched pair with POTENTIAL_MATCH edge, showing shared trading partners in between]*

---

## Scene 7 — The Full Picture

**Goal:** Summarise the value demonstrated.

### Recap for the audience

| Capability | What We Showed |
|---|---|
| **Payment Behaviour** | Frequency, volume, and regularity of transactions between entities |
| **Unbanked Identification** | High-value unbanked counterparties receiving payments from multiple banked customers |
| **Entity Resolution** | Multi-signal matching to detect unbanked entities that are duplicate banked customers, using name similarity + graph-structural trading patterns |
| **Ecosystem Mapping** | Multi-hop traversal revealing the full trading network of any customer |
| **Product Cross-Sell** | Peer comparison showing product gaps and opportunities |
| **Community Detection** | GDS-powered clustering revealing industry ecosystems and broker entities |
| **Credit Scoring Proxy** | PageRank, betweenness, and payment stability as indicators of creditworthiness |

> **Closing:** "With Neo4j, every one of these insights is a real-time traversal — not a batch job. The graph is always current, and Explore lets any business user navigate the ecosystem interactively without writing a single line of code. Entity resolution in particular shows how graph structure — shared counterparties, trading patterns — adds a dimension that traditional record-linkage tools simply cannot replicate."

---

## Tips for Running the Demo

- **Keep the canvas clean:** Expand selectively. Too many nodes at once can overwhelm the audience.
- **Use the Search bar filters:** Explore's search supports property filters; use them to narrow results.
- **Save perspectives:** After setting up your style rules (colours, sizes), save them as a named Perspective for reuse.
- **Tell the story:** Each scene above builds on the previous one. Walk through them in order for maximum impact.
- **Prepare bookmarks:** If your dataset has particularly interesting clusters or entities, bookmark their IDs so you can navigate directly during the demo.
