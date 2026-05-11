// ============================================================================
// Commercial Bank Graph — Demo Bookmark Queries
// ============================================================================
// Paste each query into Neo4j Aura Query UI and save as a Favourite/Bookmark.
// These are the queries to run during the live customer demo.
// Each is self-contained and labelled with the use case it answers.
// ============================================================================


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  OVERVIEW — Graph at a Glance                                           │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "Overview — Node & Relationship Counts"
MATCH (n)
WITH labels(n)[0] AS label, count(*) AS count
RETURN label, count ORDER BY count DESC
UNION ALL
MATCH ()-[r]->()
WITH type(r) AS label, count(*) AS count
RETURN label, count ORDER BY count DESC;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 1 — Payment Behaviour                                         │
// │  "Insights into client payment behaviour and frequency"                  │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "1a — Top 20 Trading Pairs by Frequency"
MATCH (sender:Customer)-[tw:TRADES_WITH]->(receiver:Customer)
RETURN sender.name       AS sender,
       sender.status     AS senderStatus,
       receiver.name     AS receiver,
       receiver.status   AS receiverStatus,
       tw.txCount        AS transactions,
       round(tw.amount)  AS totalZAR,
       tw.avgInterval    AS avgDaysBetween
ORDER BY tw.txCount DESC
LIMIT 20;

// BOOKMARK: "1b — Channel Breakdown for a Customer"
// Change the customerId to explore different customers
MATCH (c:Customer {customerId: 'CUST-00001'})-[:HAS_ACCOUNT]->(a)-[:SENT]->(t:Transaction)
RETURN t.channel          AS channel,
       count(t)           AS transactions,
       round(avg(t.amount))  AS avgAmount,
       round(sum(t.amount))  AS totalAmount,
       min(t.date)        AS earliest,
       max(t.date)        AS latest
ORDER BY transactions DESC;

// BOOKMARK: "1c — Monthly Payment Trend"
MATCH (c:Customer {customerId: 'CUST-00001'})-[:HAS_ACCOUNT]->(a)-[:SENT]->(t:Transaction)
WITH t.date.year AS year, t.date.month AS month, t
RETURN year, month,
       count(t)               AS transactions,
       round(sum(t.amount))   AS totalAmount
ORDER BY year, month;

// BOOKMARK: "1d — Who Does This Customer Pay the Most?"
MATCH (c:Customer {customerId: 'CUST-00001'})-[tw:TRADES_WITH]->(receiver:Customer)
RETURN receiver.name     AS paidEntity,
       receiver.status   AS status,
       tw.txCount        AS transactions,
       round(tw.amount)  AS totalZAR,
       tw.avgInterval    AS avgDaysBetween
ORDER BY tw.amount DESC
LIMIT 15;

// BOOKMARK: "1e — Who Pays This Customer the Most?"
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {customerId: 'CUST-00001'})
RETURN payer.name       AS payingEntity,
       payer.status     AS status,
       tw.txCount       AS transactions,
       round(tw.amount) AS totalZAR,
       tw.avgInterval   AS avgDaysBetween
ORDER BY tw.amount DESC
LIMIT 15;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 2 — Unbanked Client Identification                            │
// │  "Identify unbanked clients for potential sales opportunities"           │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "2a — Top 25 Unbanked Targets by Inbound Volume"
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked,
     count(DISTINCT banked) AS bankedPayers,
     sum(tw.txCount)        AS totalTx,
     sum(tw.amount)         AS totalInbound
RETURN unbanked.name       AS entity,
       unbanked.region     AS region,
       bankedPayers,
       totalTx             AS transactions,
       round(totalInbound) AS totalInboundZAR
ORDER BY totalInbound DESC
LIMIT 25;

// BOOKMARK: "2b — Multi-Payer Targets (3+ Banked Payers)"
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked,
     collect(DISTINCT banked.name) AS payerNames,
     sum(tw.amount)                AS totalZAR
WHERE size(payerNames) >= 3
RETURN unbanked.name          AS entity,
       unbanked.region        AS region,
       size(payerNames)       AS bankedPayers,
       round(totalZAR)        AS totalInboundZAR,
       payerNames[0..5]       AS samplePayers
ORDER BY totalZAR DESC
LIMIT 20;

// BOOKMARK: "2c — Unbanked Opportunity by Industry"
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked, sum(tw.amount) AS totalZAR
WHERE totalZAR > 1000000
MATCH (unbanked)-[:BELONGS_TO]->(i:Industry)
RETURN i.sector              AS sector,
       i.name                AS industry,
       count(unbanked)       AS unbankedEntities,
       round(sum(totalZAR))  AS aggregateInboundZAR
ORDER BY aggregateInboundZAR DESC;

// BOOKMARK: "2d — Visual: Expand an Unbanked Entity's Network"
// Run in Query UI for a graph view — shows who pays this unbanked entity
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked, sum(tw.amount) AS totalInbound
ORDER BY totalInbound DESC LIMIT 1
WITH unbanked
MATCH path = (other:Customer)-[tw:TRADES_WITH]-(unbanked)
RETURN path;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 3 — Ecosystem Mapping                                          │
// │  "Understand the ecosystem for strategic sales drives"                    │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "3a — Full 2-Hop Ecosystem (Graph View)"
// Returns a visual graph — best viewed in Neo4j Query UI graph mode
MATCH path = (c:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH*1..2]-(other:Customer)
RETURN path
LIMIT 200;

// BOOKMARK: "3b — Shared Counterparties Between Two Customers"
MATCH (a:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH]-(shared:Customer)-[:TRADES_WITH]-(b:Customer {customerId: 'CUST-00010'})
RETURN shared.name   AS sharedCounterparty,
       shared.status AS status,
       shared.region AS region;

// BOOKMARK: "3c — Manufacturing Sector Trading Network (Graph View)"
MATCH (c1:Customer)-[:BELONGS_TO]->(i:Industry {sector: 'Manufacturing'})
MATCH path = (c1)-[:TRADES_WITH]-(c2:Customer)
RETURN path
LIMIT 150;

// BOOKMARK: "3d — Ecosystem Size Ranking"
MATCH (c:Customer {status: 'banked'})-[:TRADES_WITH*1..2]-(other:Customer)
WHERE c <> other
WITH c, count(DISTINCT other) AS ecosystemSize
RETURN c.name        AS customer,
       c.segment     AS segment,
       c.region      AS region,
       ecosystemSize
ORDER BY ecosystemSize DESC
LIMIT 20;

// BOOKMARK: "3e — Customer + Industry + Partners (Graph View)"
// Shows a customer, their industry, and all trading partners with industries
MATCH (c:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)
MATCH (c)-[tw:TRADES_WITH]-(partner:Customer)
OPTIONAL MATCH (partner)-[:BELONGS_TO]->(pi:Industry)
RETURN c, i, tw, partner, pi
LIMIT 50;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 4 — Product Cross-Sell                                         │
// │  "Improve fit-for-purpose product offering"                              │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "4a — Customer's Current Products"
MATCH (c:Customer {customerId: 'CUST-00001'})-[h:HOLDS_PRODUCT]->(p:Product)
RETURN p.name       AS product,
       p.pillar     AS pillar,
       p.monthlyFee AS monthlyFee,
       h.since      AS heldSince
ORDER BY p.pillar, p.name;

// BOOKMARK: "4b — Peer Product Recommendations"
// Products popular with same-industry peers that this customer doesn't hold
MATCH (target:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)<-[:BELONGS_TO]-(peer:Customer)
WHERE peer <> target AND peer.status = 'banked'
MATCH (peer)-[:HOLDS_PRODUCT]->(p:Product)
WHERE NOT (target)-[:HOLDS_PRODUCT]->(p)
RETURN p.name                   AS product,
       p.pillar                 AS pillar,
       count(DISTINCT peer)     AS peersWithProduct
ORDER BY peersWithProduct DESC;

// BOOKMARK: "4c — Segment Product Penetration"
MATCH (c:Customer {status: 'banked'})
WITH c.segment AS segment, count(c) AS segTotal
MATCH (c2:Customer {status: 'banked', segment: segment})-[:HOLDS_PRODUCT]->(p:Product)
WITH segment, segTotal, p, count(DISTINCT c2) AS holders
RETURN segment,
       p.name    AS product,
       p.pillar  AS pillar,
       holders,
       segTotal,
       round(holders * 100.0 / segTotal, 1) AS penetrationPct
ORDER BY segment, penetrationPct ASC;

// BOOKMARK: "4d — Visual: Customer vs Peer Products (Graph View)"
// Shows target customer's products AND a peer's products side by side
MATCH (target:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)<-[:BELONGS_TO]-(peer:Customer)
WHERE peer.status = 'banked' AND peer <> target
WITH target, peer, rand() AS r ORDER BY r LIMIT 1
MATCH path1 = (target)-[:HOLDS_PRODUCT]->(p1:Product)
MATCH path2 = (peer)-[:HOLDS_PRODUCT]->(p2:Product)
RETURN target, peer, p1, p2;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 5 — Credit & Collateral Scoring                                │
// │  "Enable collateralised scoring on platform"                             │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "5a — Payment Diversity & Collateral Grading"
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WITH c,
     count(DISTINCT payer)    AS distinctPayers,
     sum(tw.amount)           AS totalInflowZAR,
     sum(tw.txCount)          AS totalInboundTx
MATCH (c)-[:HAS_ACCOUNT]->(a)<-[:RECEIVED_BY]-(t:Transaction)
WITH c, distinctPayers, totalInflowZAR, totalInboundTx,
     count(DISTINCT t.channel) AS channelDiversity
RETURN c.name                 AS customer,
       c.segment              AS segment,
       distinctPayers,
       channelDiversity,
       totalInboundTx,
       round(totalInflowZAR)  AS totalInflowZAR,
       round(totalInflowZAR / totalInboundTx) AS avgPaymentSize,
       CASE
         WHEN distinctPayers >= 10 AND channelDiversity >= 3 THEN 'LOW RISK'
         WHEN distinctPayers >= 5  AND channelDiversity >= 2 THEN 'MEDIUM RISK'
         ELSE 'HIGHER RISK'
       END AS collateralGrade
ORDER BY totalInflowZAR DESC
LIMIT 30;

// BOOKMARK: "5b — Revenue Concentration Risk"
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WITH c, payer, tw.amount AS payerAmount
ORDER BY payerAmount DESC
WITH c, collect({name: payer.name, amount: payerAmount}) AS payers,
     sum(payerAmount) AS totalInflow
WITH c, payers[0] AS topPayer, totalInflow
RETURN c.name                 AS customer,
       topPayer.name          AS largestPayer,
       round(topPayer.amount) AS largestPayerZAR,
       round(totalInflow)     AS totalInflowZAR,
       round(topPayer.amount * 100.0 / totalInflow, 1) AS concentrationPct
ORDER BY concentrationPct DESC
LIMIT 20;

// BOOKMARK: "5c — Payment Stability Scores"
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WHERE tw.avgInterval IS NOT NULL
WITH c,
     count(DISTINCT payer)     AS payers,
     avg(tw.avgInterval)       AS avgIntervalDays,
     stDev(tw.avgInterval)     AS intervalStdDev,
     sum(tw.amount)            AS totalInflow
WHERE payers >= 3
RETURN c.name                    AS customer,
       c.segment                 AS segment,
       payers,
       round(avgIntervalDays, 1) AS avgIntervalDays,
       round(intervalStdDev, 1)  AS intervalStdDevDays,
       round(totalInflow)        AS totalInflowZAR,
       CASE
         WHEN intervalStdDev < 10 THEN 'HIGHLY STABLE'
         WHEN intervalStdDev < 30 THEN 'STABLE'
         ELSE 'VARIABLE'
       END AS stabilityGrade
ORDER BY intervalStdDev ASC
LIMIT 20;

// BOOKMARK: "5d — Full Customer Profile (Single Customer Deep Dive)"
// Run this to get a complete picture of one customer
MATCH (c:Customer {customerId: 'CUST-00001'})
OPTIONAL MATCH (c)-[:BELONGS_TO]->(i:Industry)
OPTIONAL MATCH (c)-[:HAS_ACCOUNT]->(a:Account)
OPTIONAL MATCH (c)-[:HOLDS_PRODUCT]->(p:Product)
OPTIONAL MATCH (c)-[tw:TRADES_WITH]-(partner:Customer)
RETURN c.name AS customer, c.segment AS segment, c.region AS region,
       c.turnover AS turnover, c.riskScore AS riskScore,
       i.name AS industry, i.sector AS sector,
       count(DISTINCT a) AS accounts,
       count(DISTINCT p) AS products,
       collect(DISTINCT p.name) AS productNames,
       count(DISTINCT partner) AS tradingPartners;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  BONUS — Impressive One-Liners for Impact                                │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "Bonus — Total Value Flowing to Unbanked Entities"
MATCH (:Customer {status: 'banked'})-[tw:TRADES_WITH]->(:Customer {status: 'unbanked'})
RETURN count(tw)        AS tradingRelationships,
       round(sum(tw.amount)) AS totalValueToUnbanked_ZAR;

// BOOKMARK: "Bonus — Largest Single Payment Relationship"
MATCH (a:Customer)-[tw:TRADES_WITH]->(b:Customer)
RETURN a.name AS from, b.name AS to,
       a.status AS fromStatus, b.status AS toStatus,
       round(tw.amount) AS totalZAR, tw.txCount AS transactions
ORDER BY tw.amount DESC
LIMIT 1;

// BOOKMARK: "Bonus — The 6 Degrees of the network"
// How many hops to connect any two customers?
MATCH path = shortestPath(
  (a:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH*]-(b:Customer {customerId: 'CUST-00100'})
)
RETURN length(path) AS hops,
       [n IN nodes(path) | n.name] AS pathNames;


// ┌──────────────────────────────────────────────────────────────────────────┐
// │  USE CASE 6 — Entity Resolution                                         │
// │  "Identify unbanked entities that are duplicates of banked customers"    │
// └──────────────────────────────────────────────────────────────────────────┘

// BOOKMARK: "6a — Top Entity Resolution Matches"
// Requires: run cypher/06_entity_resolution.cypher first
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
RETURN b.name         AS bankedCustomer,
       u.name         AS unbankedEntity,
       m.confidence   AS confidence,
       m.nameSim      AS nameSimilarity,
       m.industrySim  AS sameIndustry,
       m.regionSim    AS sameRegion,
       m.tradingSim   AS tradingOverlap
ORDER BY m.confidence DESC
LIMIT 20;

// BOOKMARK: "6b — High-Confidence Matches (>= 0.70)"
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
RETURN b.name         AS bankedCustomer,
       b.region       AS region,
       u.name         AS matchedEntity,
       m.confidence   AS confidence,
       m.nameSim      AS nameSimilarity,
       m.tradingSim   AS tradingOverlap
ORDER BY m.confidence DESC;

// BOOKMARK: "6c — Visual: ER Match with Overlapping Networks (Graph View)"
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
WITH b, u, m ORDER BY m.confidence DESC LIMIT 1
MATCH pathB = (b)-[:TRADES_WITH]-(bp:Customer)
MATCH pathU = (u)-[:TRADES_WITH]-(up:Customer)
RETURN b, u, m, bp, up;

// BOOKMARK: "6d — Hidden Trading Volume (Revenue at Risk)"
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.60
OPTIONAL MATCH ()-[tw:TRADES_WITH]-(u)
WITH b, u, m, sum(tw.amount) AS unbankedVolume
RETURN b.name            AS bankedCustomer,
       u.name            AS duplicateEntity,
       m.confidence      AS confidence,
       round(unbankedVolume) AS hiddenTradingVolumeZAR
ORDER BY unbankedVolume DESC
LIMIT 15;

// BOOKMARK: "6e — New Partners Revealed by ER"
MATCH (b:Customer)-[m:POTENTIAL_MATCH]->(u:Customer)
WHERE m.confidence >= 0.70
OPTIONAL MATCH (u)-[:TRADES_WITH]-(partner:Customer)
WHERE NOT (b)-[:TRADES_WITH]-(partner)
WITH b, u, m, collect(DISTINCT partner.name) AS newPartners
RETURN b.name            AS bankedCustomer,
       u.name            AS matchedEntity,
       m.confidence      AS confidence,
       size(newPartners) AS newPartnersRevealed,
       newPartners[..5]  AS sampleNewPartners
ORDER BY size(newPartners) DESC;
