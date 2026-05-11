// ============================================================================
// Commercial Bank Graph — Entity Resolution Pipeline
// Run AFTER data load (02_load_data.cypher) and TRADES_WITH creation.
// Optionally run AFTER GDS algorithms (04_gds_algorithms.cypher) for
// community-based signals.
//
// Requires: APOC plugin (included in Neo4j Aura).
//
// This script identifies unbanked entities that are likely the same
// real-world company as an existing banked customer, using four signals:
//   1. Name similarity   (Jaro-Winkler fuzzy match)
//   2. Industry match     (same SIC code)
//   3. Region match       (same province)
//   4. Trading overlap    (Jaccard similarity on counterparty sets)
//
// The composite score is written as a POTENTIAL_MATCH relationship between
// the banked customer and unbanked entity.
// ============================================================================


// ──────────────────────────────────────────────────────────────────────────────
// STEP 0 — Create a fulltext index for candidate blocking
// Limits the cartesian product by pre-filtering on approximate name match.
// ──────────────────────────────────────────────────────────────────────────────

CREATE FULLTEXT INDEX customer_name_fulltext IF NOT EXISTS
FOR (c:Customer) ON EACH [c.name];


// ──────────────────────────────────────────────────────────────────────────────
// STEP 1 — Candidate Generation (Blocking)
// For each unbanked entity, find banked candidates whose names are similar
// using the fulltext index with Lucene fuzzy syntax (~).
// This narrows the search space before computing expensive graph signals.
// ──────────────────────────────────────────────────────────────────────────────

// Preview: which banked customers does the fulltext index surface for each
// unbanked entity? (Run this to verify blocking quality before scoring.)

MATCH (u:Customer {status: 'unbanked'})
WITH u, replace(u.name, '(', '') AS cleanName
WITH u, split(cleanName, ' ')[0] + '~' AS fuzzyTerm
CALL db.index.fulltext.queryNodes('customer_name_fulltext', fuzzyTerm)
YIELD node AS candidate, score AS ftScore
WHERE candidate.status = 'banked' AND candidate <> u AND ftScore > 0.5
RETURN u.name AS unbankedEntity,
       candidate.name AS bankedCandidate,
       round(ftScore, 3) AS fulltextScore
ORDER BY ftScore DESC
LIMIT 50;


// ──────────────────────────────────────────────────────────────────────────────
// STEP 2 — Multi-Signal Scoring & POTENTIAL_MATCH Creation
// For each (unbanked, banked candidate) pair that passes blocking, compute
// four signals and a weighted composite confidence score.
//
// Signal weights:
//   Name similarity    0.40   (Jaro-Winkler — good for prefix-heavy names)
//   Industry match     0.20   (binary: same SIC code)
//   Region match       0.15   (binary: same province)
//   Trading overlap    0.25   (Jaccard on TRADES_WITH neighbour sets)
//
// Only pairs with composite score >= 0.45 are persisted.
// ──────────────────────────────────────────────────────────────────────────────

// Clean up previous runs
MATCH ()-[r:POTENTIAL_MATCH]->() DELETE r;

// Run the scoring pipeline
:auto
MATCH (u:Customer {status: 'unbanked'})
WITH u, replace(replace(u.name, '(', ''), ')', '') AS cleanName
WITH u, reduce(term = '', w IN split(cleanName, ' ')[..2] | term + w + '~ ') AS fuzzyTerm
CALL db.index.fulltext.queryNodes('customer_name_fulltext', trim(fuzzyTerm))
YIELD node AS b, score AS ftScore
WHERE b.status = 'banked' AND ftScore > 0.3
CALL {
  WITH u, b

  // Signal 1 — Name similarity (Jaro-Winkler: convert distance to similarity)
  WITH u, b,
       1.0 - apoc.text.jaroWinklerDistance(toLower(u.name), toLower(b.name)) AS nameSim

  // Signal 2 — Industry match
  OPTIONAL MATCH (u)-[:BELONGS_TO]->(iu:Industry)
  OPTIONAL MATCH (b)-[:BELONGS_TO]->(ib:Industry)
  WITH u, b, nameSim,
       CASE WHEN iu.sicCode = ib.sicCode THEN 1.0 ELSE 0.0 END AS industrySim

  // Signal 3 — Region match
  WITH u, b, nameSim, industrySim,
       CASE WHEN u.region = b.region THEN 1.0 ELSE 0.0 END AS regionSim

  // Signal 4 — Trading partner overlap (Jaccard on TRADES_WITH neighbours)
  OPTIONAL MATCH (u)-[:TRADES_WITH]-(uPartner:Customer)
  WITH u, b, nameSim, industrySim, regionSim,
       collect(DISTINCT uPartner.customerId) AS uPartners
  OPTIONAL MATCH (b)-[:TRADES_WITH]-(bPartner:Customer)
  WITH u, b, nameSim, industrySim, regionSim, uPartners,
       collect(DISTINCT bPartner.customerId) AS bPartners
  WITH u, b, nameSim, industrySim, regionSim,
       [x IN uPartners WHERE x IN bPartners] AS intersection,
       apoc.coll.union(uPartners, bPartners) AS unionSet
  WITH u, b, nameSim, industrySim, regionSim,
       CASE WHEN size(unionSet) = 0 THEN 0.0
            ELSE toFloat(size(intersection)) / size(unionSet)
       END AS tradingSim

  // Composite score
  WITH u, b, nameSim, industrySim, regionSim, tradingSim,
       (0.40 * nameSim +
        0.20 * industrySim +
        0.15 * regionSim +
        0.25 * tradingSim) AS confidence

  WHERE confidence >= 0.45

  MERGE (b)-[m:POTENTIAL_MATCH]->(u)
  SET m.confidence    = round(confidence, 4),
      m.nameSim       = round(nameSim, 4),
      m.industrySim   = industrySim,
      m.regionSim     = regionSim,
      m.tradingSim    = round(tradingSim, 4)
} IN TRANSACTIONS OF 100 ROWS;


// ──────────────────────────────────────────────────────────────────────────────
// STEP 3 — Results & Verification
// ──────────────────────────────────────────────────────────────────────────────

// 3a. Summary statistics
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
RETURN count(m)                       AS totalMatches,
       round(avg(m.confidence), 3)    AS avgConfidence,
       round(min(m.confidence), 3)    AS minConfidence,
       round(max(m.confidence), 3)    AS maxConfidence;

// 3b. All matches ranked by confidence
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
RETURN b.customerId   AS bankedId,
       b.name         AS bankedName,
       u.customerId   AS unbankedId,
       u.name         AS unbankedName,
       m.confidence   AS confidence,
       m.nameSim      AS nameSimilarity,
       m.industrySim  AS sameIndustry,
       m.regionSim    AS sameRegion,
       m.tradingSim   AS tradingOverlap
ORDER BY m.confidence DESC;

// 3c. High-confidence matches (>= 0.70) — candidates for auto-merge
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
RETURN b.name           AS bankedCustomer,
       u.name           AS unbankedEntity,
       m.confidence     AS confidence,
       b.region         AS bankedRegion,
       u.region         AS unbankedRegion
ORDER BY m.confidence DESC;

// 3d. Medium-confidence matches (0.45–0.70) — candidates for manual review
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.45 AND m.confidence < 0.70
RETURN b.name           AS bankedCustomer,
       u.name           AS unbankedEntity,
       m.confidence     AS confidence,
       m.nameSim        AS nameSimilarity,
       m.tradingSim     AS tradingOverlap
ORDER BY m.confidence DESC;


// ──────────────────────────────────────────────────────────────────────────────
// STEP 4 — Signal Decomposition Queries
// Useful for understanding which signals drive individual matches.
// ──────────────────────────────────────────────────────────────────────────────

// 4a. Matches driven primarily by name (high nameSim, low tradingSim)
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.nameSim > 0.80 AND m.tradingSim < 0.10
RETURN b.name AS bankedName, u.name AS unbankedName,
       m.confidence, m.nameSim, m.tradingSim
ORDER BY m.nameSim DESC
LIMIT 15;

// 4b. Matches driven primarily by graph structure (high tradingSim, lower nameSim)
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.tradingSim > 0.15
RETURN b.name AS bankedName, u.name AS unbankedName,
       m.confidence, m.nameSim, m.tradingSim
ORDER BY m.tradingSim DESC
LIMIT 15;

// 4c. Matches where all four signals agree (strongest evidence)
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.nameSim > 0.60 AND m.industrySim = 1.0
      AND m.regionSim = 1.0 AND m.tradingSim > 0.05
RETURN b.name AS bankedName, u.name AS unbankedName,
       m.confidence, m.nameSim, m.tradingSim
ORDER BY m.confidence DESC
LIMIT 15;


// ──────────────────────────────────────────────────────────────────────────────
// STEP 5 — Business Impact Queries
// Show the downstream value of entity resolution.
// ──────────────────────────────────────────────────────────────────────────────

// 5a. Merged view: combine banked customer profile with unbanked entity's
//     trading network to reveal the full picture.
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
OPTIONAL MATCH (u)-[tw:TRADES_WITH]-(partner:Customer)
WHERE NOT (b)-[:TRADES_WITH]-(partner)
WITH b, u, m, collect(DISTINCT partner.name) AS hiddenPartners,
     count(DISTINCT partner) AS newPartnersRevealed
RETURN b.name            AS bankedCustomer,
       u.name            AS matchedEntity,
       m.confidence      AS confidence,
       newPartnersRevealed,
       hiddenPartners[..5] AS sampleNewPartners
ORDER BY newPartnersRevealed DESC;

// 5b. Revenue at risk: total trading volume flowing through unbanked entities
//     that are actually existing customers.
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.60
OPTIONAL MATCH ()-[tw:TRADES_WITH]-(u)
WITH b, u, m, sum(tw.amount) AS unbankedVolume
RETURN b.name            AS bankedCustomer,
       u.name            AS duplicateEntity,
       m.confidence      AS confidence,
       round(unbankedVolume) AS hiddenTradingVolumeZAR
ORDER BY unbankedVolume DESC
LIMIT 20;

// 5c. Visual: graph view of a high-confidence match showing both entities
//     and their trading networks side by side.
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
WITH b, u, m ORDER BY m.confidence DESC LIMIT 1
MATCH pathB = (b)-[:TRADES_WITH]-(bp:Customer)
MATCH pathU = (u)-[:TRADES_WITH]-(up:Customer)
RETURN b, u, m, bp, up;
