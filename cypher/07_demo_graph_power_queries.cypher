// ============================================================================
// Commercial Bank Graph — Demo queries highlighting graph-native insights
// ============================================================================
// Curated for live demos: multi-hop ecosystem, fan-in (multi-payer unbanked),
// structural patterns (cross-sell), shortest paths, and entity resolution.
//
// Most overlap with cypher/05_demo_bookmarks.cypher — this file groups them
// as a single "graph power" narrative. Run in Neo4j Aura Query UI (use graph
// mode where noted).
//
// Prerequisites:
//   - Standard load: 02_load_data.cypher (and TRADES_WITH edges).
//   - Entity resolution blocks (§9): run 06_entity_resolution.cypher first.
// ============================================================================


// ─────────────────────────────────────────────────────────────────────────────
// 1 — Graph at a glance (table)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (n)
WITH labels(n)[0] AS label, count(*) AS count
RETURN label, count ORDER BY count DESC
UNION ALL
MATCH ()-[r]->()
WITH type(r) AS label, count(*) AS count
RETURN label, count ORDER BY count DESC;


// ─────────────────────────────────────────────────────────────────────────────
// 2 — Multi-hop ecosystem (GRAPH VIEW — swap customerId)
// ─────────────────────────────────────────────────────────────────────────────

MATCH path = (c:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH*1..2]-(other:Customer)
RETURN path
LIMIT 200;


// ─────────────────────────────────────────────────────────────────────────────
// 3 — Ecosystem size ranking — distinct entities within 2 hops (table)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (c:Customer {status: 'banked'})-[:TRADES_WITH*1..2]-(other:Customer)
WHERE c <> other
WITH c, count(DISTINCT other) AS ecosystemSize
RETURN c.name AS customer,
       c.segment AS segment,
       c.region AS region,
       ecosystemSize
ORDER BY ecosystemSize DESC
LIMIT 20;


// ─────────────────────────────────────────────────────────────────────────────
// 4 — Shared counterparties between two customers (table — adjust IDs)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (a:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH]-(shared:Customer)-[:TRADES_WITH]-(b:Customer {customerId: 'CUST-00010'})
RETURN shared.name AS sharedCounterparty,
       shared.status AS status,
       shared.region AS region;


// ─────────────────────────────────────────────────────────────────────────────
// 5 — Multi-payer unbanked conversion targets (table)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked,
     collect(DISTINCT banked.name) AS payerNames,
     sum(tw.amount) AS totalZAR
WHERE size(payerNames) >= 3
RETURN unbanked.name AS entity,
       unbanked.region AS region,
       size(payerNames) AS bankedPayers,
       round(totalZAR) AS totalInboundZAR,
       payerNames[0..5] AS samplePayers
ORDER BY totalZAR DESC
LIMIT 20;


// ─────────────────────────────────────────────────────────────────────────────
// 6 — Peer-based cross-sell (same industry, product peer holds, target does not)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (target:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)<-[:BELONGS_TO]-(peer:Customer)
WHERE peer <> target AND peer.status = 'banked'
MATCH (peer)-[:HOLDS_PRODUCT]->(p:Product)
WHERE NOT (target)-[:HOLDS_PRODUCT]->(p)
RETURN p.name AS product,
       p.pillar AS pillar,
       count(DISTINCT peer) AS peersWithProduct
ORDER BY peersWithProduct DESC;


// ─────────────────────────────────────────────────────────────────────────────
// 7 — Collateral-style grading from inbound graph + channel diversity (table)
// ─────────────────────────────────────────────────────────────────────────────

MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WITH c,
     count(DISTINCT payer) AS distinctPayers,
     sum(tw.amount) AS totalInflowZAR,
     sum(tw.txCount) AS totalInboundTx
MATCH (c)-[:HAS_ACCOUNT]->(a)<-[:RECEIVED_BY]-(t:Transaction)
WITH c, distinctPayers, totalInflowZAR, totalInboundTx,
     count(DISTINCT t.channel) AS channelDiversity
RETURN c.name AS customer,
       distinctPayers,
       channelDiversity,
       round(totalInflowZAR) AS totalInflowZAR,
       CASE
         WHEN distinctPayers >= 10 AND channelDiversity >= 3 THEN 'LOW RISK'
         WHEN distinctPayers >= 5  AND channelDiversity >= 2 THEN 'MEDIUM RISK'
         ELSE 'HIGHER RISK'
       END AS collateralGrade
ORDER BY totalInflowZAR DESC
LIMIT 30;


// ─────────────────────────────────────────────────────────────────────────────
// 8 — Shortest trading path between two customers (table — may return 0 rows)
// ─────────────────────────────────────────────────────────────────────────────

MATCH path = shortestPath(
  (a:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH*]-(b:Customer {customerId: 'CUST-00100'})
)
RETURN length(path) AS hops,
       [n IN nodes(path) | n.name] AS pathNames;


// ─────────────────────────────────────────────────────────────────────────────
// 9 — Entity resolution (requires 06_entity_resolution.cypher)
// ─────────────────────────────────────────────────────────────────────────────

// 9a — Top matches with signal breakdown (table)

MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
RETURN b.name AS bankedCustomer,
       u.name AS unbankedEntity,
       m.confidence AS confidence,
       m.nameSim AS nameSimilarity,
       m.industrySim AS sameIndustry,
       m.regionSim AS sameRegion,
       m.tradingSim AS tradingOverlap
ORDER BY m.confidence DESC
LIMIT 20;

// 9b — GRAPH VIEW: one high-confidence pair + trading neighbours

MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
WITH b, u, m ORDER BY m.confidence DESC LIMIT 1
MATCH pathB = (b)-[:TRADES_WITH]-(bp:Customer)
MATCH pathU = (u)-[:TRADES_WITH]-(up:Customer)
RETURN b, u, m, bp, up;
