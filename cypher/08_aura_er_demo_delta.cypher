// ============================================================================
// Aura delta — high-confidence ER demo data (copy/paste into Query UI)
// ============================================================================
// Adds one banked + one unbanked customer with a legal-name variant, three
// shared trading partners (so trading Jaccard = 1.0), then creates POTENTIAL_MATCH
// using the same weights as 06_entity_resolution.cypher.
//
// Requires: APOC (Neo4j Aura — enabled by default).
//
// Safe to re-run (MERGE / ON CREATE). IDs are prefixed so they do not collide
// with synthetic CSV customers.
//
// Neo4j Aura Query UI: paste the whole file and run once if multi-statement
// execution is enabled; otherwise run each section down to the next ";".
//
// Optional cleanup before first run if you need a reset:
//   MATCH (c:Customer)
//   WHERE c.customerId STARTS WITH 'CUST-AURA-ER-' OR c.customerId STARTS WITH 'UNB-AURA-ER-'
//   DETACH DELETE c;
//   MATCH (i:Industry {sicCode: '9998'}) DETACH DELETE i;
// ============================================================================

// --- Reference industry (dedicated sic code — not in bundled CSV list) ---
MERGE (i:Industry {sicCode: '9998'})
SET i.name = 'Sample demo industry',
    i.sector = 'Technology';

// --- Core pair: same region + industry; unbanked name is legal suffix of banked ---
MERGE (b:Customer {customerId: 'CUST-AURA-ER-B001'})
SET b.name               = 'Commercial Bank Aura Demo Metal Works',
    b.registrationNumber = 'demo/aura-er/001',
    b.region             = 'Gauteng',
    b.segment            = 'SME',
    b.status             = 'banked',
    b.turnover           = 12000000,
    b.riskScore          = 0.35;

MERGE (u:Customer {customerId: 'UNB-AURA-ER-U001'})
SET u.name   = 'Commercial Bank Aura Demo Metal Works (Pty) Ltd',
    u.region = 'Gauteng',
    u.status = 'unbanked';

MERGE (b)-[:BELONGS_TO]->(i)
MERGE (u)-[:BELONGS_TO]->(i);

// --- Three banked “suppliers” only connected to b and u → perfect overlap ---
MATCH (i:Industry {sicCode: '9998'})
UNWIND [
  {id: 'CUST-AURA-ER-P001', name: 'Commercial Bank Aura Demo Supplier North'},
  {id: 'CUST-AURA-ER-P002', name: 'Commercial Bank Aura Demo Supplier South'},
  {id: 'CUST-AURA-ER-P003', name: 'Commercial Bank Aura Demo Supplier East'}
] AS row
MERGE (p:Customer {customerId: row.id})
SET p.name               = row.name,
    p.registrationNumber = 'demo/aura-er/partner',
    p.region             = 'Gauteng',
    p.segment            = 'SME',
    p.status             = 'banked',
    p.turnover           = 5000000,
    p.riskScore          = 0.5
MERGE (p)-[:BELONGS_TO]->(i);

// --- Aggregated trading edges (no Transaction rows required) ---
MATCH (b:Customer {customerId: 'CUST-AURA-ER-B001'})
MATCH (u:Customer {customerId: 'UNB-AURA-ER-U001'})
UNWIND ['CUST-AURA-ER-P001', 'CUST-AURA-ER-P002', 'CUST-AURA-ER-P003'] AS pid
MATCH (p:Customer {customerId: pid})
MERGE (b)-[tb:TRADES_WITH]->(p)
  ON CREATE SET tb.amount = 250000, tb.txCount = 8, tb.avgInterval = 12.0
MERGE (u)-[tu:TRADES_WITH]->(p)
  ON CREATE SET tu.amount = 180000, tu.txCount = 6, tu.avgInterval = 15.0;

// --- Score & persist POTENTIAL_MATCH (same formula as 06_entity_resolution) ---
MATCH (b:Customer {customerId: 'CUST-AURA-ER-B001'})
MATCH (u:Customer {customerId: 'UNB-AURA-ER-U001'})
OPTIONAL MATCH (u)-[:BELONGS_TO]->(iu:Industry)
OPTIONAL MATCH (b)-[:BELONGS_TO]->(ib:Industry)
OPTIONAL MATCH (u)-[:TRADES_WITH]-(up:Customer)
WITH b, u, iu, ib, collect(DISTINCT up.customerId) AS uPartners
OPTIONAL MATCH (b)-[:TRADES_WITH]-(bp:Customer)
WITH b, u, iu, ib, uPartners, collect(DISTINCT bp.customerId) AS bPartners
WITH b, u,
     1.0 - apoc.text.jaroWinklerDistance(toLower(u.name), toLower(b.name)) AS nameSim,
     CASE
       WHEN iu IS NOT NULL AND ib IS NOT NULL AND iu.sicCode = ib.sicCode THEN 1.0
       ELSE 0.0
     END AS industrySim,
     CASE WHEN u.region = b.region THEN 1.0 ELSE 0.0 END AS regionSim,
     uPartners,
     bPartners
WITH b, u, nameSim, industrySim, regionSim,
     [x IN uPartners WHERE x IN bPartners] AS intersection,
     apoc.coll.union(uPartners, bPartners) AS unionSet
WITH b, u, nameSim, industrySim, regionSim,
     CASE WHEN size(unionSet) = 0 THEN 0.0
          ELSE toFloat(size(intersection)) / size(unionSet)
     END AS tradingSim
WITH b, u, nameSim, industrySim, regionSim, tradingSim,
     (0.40 * nameSim + 0.20 * industrySim + 0.15 * regionSim + 0.25 * tradingSim) AS confidence
WHERE confidence >= 0.45
MERGE (b)-[m:POTENTIAL_MATCH]->(u)
SET m.confidence  = round(confidence, 4),
    m.nameSim     = round(nameSim, 4),
    m.industrySim = industrySim,
    m.regionSim   = regionSim,
    m.tradingSim  = round(tradingSim, 4)
RETURN b.name AS bankedCustomer,
       u.name AS unbankedEntity,
       round(confidence, 4) AS confidence,
       round(nameSim, 4) AS nameSimilarity,
       tradingSim AS tradingOverlap;

// --- Verify high-confidence query (same filter as 06 step 3c) ---
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
  AND b.customerId = 'CUST-AURA-ER-B001'
RETURN b.name AS bankedCustomer,
       u.name AS unbankedEntity,
       m.confidence AS confidence;

// ============================================================================
// REPAIR — use when demo Customers + TRADES_WITH exist but BELONGS_TO / POTENTIAL_MATCH are missing
//           (e.g. only part of this file ran). Run REPAIR 1, then REPAIR 2, each as its own query.
// ============================================================================

// REPAIR 1 — attach Industry 9998 to all five Aura demo customers
MERGE (i:Industry {sicCode: '9998'})
SET i.name = 'Sample demo industry',
    i.sector = 'Technology'
WITH i
MATCH (c:Customer)
WHERE c.customerId IN [
  'CUST-AURA-ER-B001',
  'UNB-AURA-ER-U001',
  'CUST-AURA-ER-P001',
  'CUST-AURA-ER-P002',
  'CUST-AURA-ER-P003'
]
MERGE (c)-[:BELONGS_TO]->(i)
RETURN count(*) AS customersLinked;

// REPAIR 2 — same scoring + POTENTIAL_MATCH as section “Score & persist” above
MATCH (b:Customer {customerId: 'CUST-AURA-ER-B001'})
MATCH (u:Customer {customerId: 'UNB-AURA-ER-U001'})
OPTIONAL MATCH (u)-[:BELONGS_TO]->(iu:Industry)
OPTIONAL MATCH (b)-[:BELONGS_TO]->(ib:Industry)
OPTIONAL MATCH (u)-[:TRADES_WITH]-(up:Customer)
WITH b, u, iu, ib, collect(DISTINCT up.customerId) AS uPartners
OPTIONAL MATCH (b)-[:TRADES_WITH]-(bp:Customer)
WITH b, u, iu, ib, uPartners, collect(DISTINCT bp.customerId) AS bPartners
WITH b, u,
     1.0 - apoc.text.jaroWinklerDistance(toLower(u.name), toLower(b.name)) AS nameSim,
     CASE
       WHEN iu IS NOT NULL AND ib IS NOT NULL AND iu.sicCode = ib.sicCode THEN 1.0
       ELSE 0.0
     END AS industrySim,
     CASE WHEN u.region = b.region THEN 1.0 ELSE 0.0 END AS regionSim,
     uPartners,
     bPartners
WITH b, u, nameSim, industrySim, regionSim,
     [x IN uPartners WHERE x IN bPartners] AS intersection,
     apoc.coll.union(uPartners, bPartners) AS unionSet
WITH b, u, nameSim, industrySim, regionSim,
     CASE WHEN size(unionSet) = 0 THEN 0.0
          ELSE toFloat(size(intersection)) / size(unionSet)
     END AS tradingSim
WITH b, u, nameSim, industrySim, regionSim, tradingSim,
     (0.40 * nameSim + 0.20 * industrySim + 0.15 * regionSim + 0.25 * tradingSim) AS confidence
WHERE confidence >= 0.45
MERGE (b)-[m:POTENTIAL_MATCH]->(u)
SET m.confidence  = round(confidence, 4),
    m.nameSim     = round(nameSim, 4),
    m.industrySim = industrySim,
    m.regionSim   = regionSim,
    m.tradingSim  = round(tradingSim, 4)
RETURN b.name AS bankedCustomer,
       u.name AS unbankedEntity,
       round(confidence, 4) AS confidence,
       round(nameSim, 4) AS nameSimilarity,
       tradingSim AS tradingOverlap;

// ============================================================================
// Troubleshooting — run these ONE AT A TIME if anything above returns nothing
// ============================================================================
//
// A) Confirm demo nodes exist (expect 5 Customer rows):
// MATCH (c:Customer)
// WHERE c.customerId STARTS WITH 'CUST-AURA-ER-' OR c.customerId STARTS WITH 'UNB-AURA-ER-'
// RETURN c.customerId, c.name, c.status ORDER BY c.customerId;
//
// B) Confirm BELONGS_TO industry (expect 5 rows):
// MATCH (c:Customer)-[:BELONGS_TO]->(i:Industry)
// WHERE c.customerId STARTS WITH 'CUST-AURA-ER-' OR c.customerId STARTS WITH 'UNB-AURA-ER-'
// RETURN c.customerId, i.sicCode, i.name;
//
// C) Confirm TRADES_WITH to partners (expect 6 rows — b→p and u→p):
// MATCH (c:Customer)-[tw:TRADES_WITH]->(p:Customer)
// WHERE c.customerId IN ['CUST-AURA-ER-B001','UNB-AURA-ER-U001']
// RETURN c.customerId, p.customerId, tw.txCount;
//
// D) Confirm POTENTIAL_MATCH exists:
// MATCH (b:Customer {customerId:'CUST-AURA-ER-B001'})-[m:POTENTIAL_MATCH]->(u:Customer {customerId:'UNB-AURA-ER-U001'})
// RETURN m;
//
// If B returns nothing but A + C OK: run REPAIR 1 then REPAIR 2 in this file.
// If D returns nothing after REPAIR 1: run REPAIR 2; check for APOC errors.
// Aura Query UI often runs ONE statement per click — paste each ;-terminated
// block separately if “no records” after a full paste.
