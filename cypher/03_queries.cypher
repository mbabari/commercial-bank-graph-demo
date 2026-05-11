// ============================================================================
// Commercial Bank Graph — Business Queries for Neo4j Query UI
// Each query maps to a user story from the PoV planning document.
// ============================================================================


// ──────────────────────────────────────────────────────────────────────────────
// QUERY 1 — Payment Behaviour Analysis
// User Story: "As a data scientist I want to gain insights into client payment
//   behaviour and frequency to provide valuable insights into working capital
//   requirements for new opportunities in short-term facilities."
// ──────────────────────────────────────────────────────────────────────────────

// 1a. Top 20 customer pairs by payment frequency
MATCH (sender:Customer)-[tw:TRADES_WITH]->(receiver:Customer)
RETURN sender.name       AS senderName,
       sender.status     AS senderStatus,
       receiver.name     AS receiverName,
       receiver.status   AS receiverStatus,
       tw.txCount        AS transactionCount,
       tw.amount         AS totalAmountZAR,
       tw.avgInterval    AS avgDaysBetweenPayments
ORDER BY tw.txCount DESC
LIMIT 20;

// 1b. Payment channel breakdown for a specific customer
MATCH (c:Customer {customerId: 'CUST-00001'})-[:HAS_ACCOUNT]->(a)-[:SENT]->(t:Transaction)
RETURN t.channel          AS channel,
       count(t)           AS txCount,
       round(avg(t.amount), 2)  AS avgAmount,
       round(sum(t.amount), 2)  AS totalAmount,
       min(t.date)        AS earliest,
       max(t.date)        AS latest
ORDER BY txCount DESC;

// 1c. Monthly payment trend for a customer
MATCH (c:Customer {customerId: 'CUST-00001'})-[:HAS_ACCOUNT]->(a)-[:SENT]->(t:Transaction)
WITH t.date.year AS year, t.date.month AS month, t
RETURN year, month,
       count(t)           AS txCount,
       round(sum(t.amount), 2) AS totalAmount
ORDER BY year, month;


// ──────────────────────────────────────────────────────────────────────────────
// QUERY 2 — Unbanked Client Identification
// User Story: "As a data scientist I want to identify unbanked clients for
//   potential sales opportunities and increase sales within our banked and
//   unbanked customer base."
// ──────────────────────────────────────────────────────────────────────────────

// 2a. Top unbanked entities by inbound payment volume from banked customers
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked,
     count(DISTINCT banked) AS bankedPayerCount,
     sum(tw.amount)         AS totalInboundZAR,
     sum(tw.txCount)        AS totalTxCount
RETURN unbanked.customerId  AS entityId,
       unbanked.name        AS entityName,
       unbanked.region      AS region,
       bankedPayerCount,
       totalTxCount,
       round(totalInboundZAR, 2) AS totalInboundZAR
ORDER BY totalInboundZAR DESC
LIMIT 25;

// 2b. Unbanked entities receiving payments from 3+ distinct banked customers
//     (high-confidence conversion targets)
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked, collect(DISTINCT banked) AS payers, sum(tw.amount) AS totalZAR
WHERE size(payers) >= 3
UNWIND payers AS payer
RETURN unbanked.name AS unbankedEntity,
       unbanked.region AS region,
       size(payers) AS distinctBankedPayers,
       round(totalZAR, 2) AS totalInboundZAR,
       collect(payer.name) AS payerNames
ORDER BY totalZAR DESC
LIMIT 20;

// 2c. Industry distribution of high-value unbanked entities
MATCH (banked:Customer {status: 'banked'})-[tw:TRADES_WITH]->(unbanked:Customer {status: 'unbanked'})
WITH unbanked, sum(tw.amount) AS totalZAR
WHERE totalZAR > 1000000
MATCH (unbanked)-[:BELONGS_TO]->(i:Industry)
RETURN i.name AS industry, i.sector AS sector,
       count(unbanked) AS unbankedCount,
       round(sum(totalZAR), 2) AS aggregateInboundZAR
ORDER BY aggregateInboundZAR DESC;


// ──────────────────────────────────────────────────────────────────────────────
// QUERY 3 — Ecosystem Mapping
// User Story: "As a data scientist I want to understand the ecosystem of our
//   customers to determine strategic sales drive across the ecosystem for
//   long term growth."
// ──────────────────────────────────────────────────────────────────────────────

// 3a. Full trading ecosystem for a customer (2-hop traversal)
MATCH path = (c:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH*1..2]-(other:Customer)
RETURN path;

// 3b. Shared counterparties — find entities that two specific customers both
//     trade with, revealing ecosystem overlap
MATCH (a:Customer {customerId: 'CUST-00001'})-[:TRADES_WITH]-(shared:Customer)-[:TRADES_WITH]-(b:Customer {customerId: 'CUST-00010'})
RETURN shared.name AS sharedCounterparty,
       shared.status AS status,
       shared.region AS region;

// 3c. Industry ecosystem — all trading relationships within an industry sector
MATCH (c1:Customer)-[:BELONGS_TO]->(i:Industry {sector: 'Manufacturing'})
MATCH (c1)-[tw:TRADES_WITH]-(c2:Customer)
RETURN c1.name AS customer1, c2.name AS customer2,
       tw.amount AS totalTradeZAR, tw.txCount AS txCount
ORDER BY tw.amount DESC
LIMIT 50;

// 3d. Ecosystem size per customer — how many distinct entities each customer
//     trades with (direct + 1-hop)
MATCH (c:Customer {status: 'banked'})-[:TRADES_WITH*1..2]-(other:Customer)
WHERE c <> other
WITH c, count(DISTINCT other) AS ecosystemSize
RETURN c.name AS customer, c.segment AS segment, ecosystemSize
ORDER BY ecosystemSize DESC
LIMIT 20;


// ──────────────────────────────────────────────────────────────────────────────
// QUERY 4 — Product Fit / Cross-Sell
// User Story: "As a data scientist I want to understand the customer's business
//   to improve our fit-for-purpose product offering to the customer as well as
//   improving credit decisioning based on improved subject knowledge."
// ──────────────────────────────────────────────────────────────────────────────

// 4a. Products held by industry peers but NOT by a target customer
//     (cross-sell recommendations)
MATCH (target:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)
MATCH (peer:Customer)-[:BELONGS_TO]->(i)
WHERE peer <> target AND peer.status = 'banked'
MATCH (peer)-[:HOLDS_PRODUCT]->(p:Product)
WHERE NOT (target)-[:HOLDS_PRODUCT]->(p)
WITH p, count(DISTINCT peer) AS peersHolding
RETURN p.name AS product, p.pillar AS pillar,
       peersHolding,
       round(peersHolding * 100.0 /
         (SIZE {
           MATCH (c:Customer)-[:BELONGS_TO]->(i2:Industry)
           WHERE i2 = (
             MATCH (target2:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(ind) RETURN ind LIMIT 1
           )
           RETURN c
         }), 1) AS peerAdoptionPct
ORDER BY peersHolding DESC;

// 4b. Simpler cross-sell: products popular in the same industry that a
//     customer does not hold
MATCH (target:Customer {customerId: 'CUST-00001'})-[:BELONGS_TO]->(i:Industry)<-[:BELONGS_TO]-(peer:Customer)
WHERE peer <> target AND peer.status = 'banked'
MATCH (peer)-[:HOLDS_PRODUCT]->(p:Product)
WHERE NOT (target)-[:HOLDS_PRODUCT]->(p)
RETURN p.productId, p.name AS product, p.pillar,
       count(DISTINCT peer) AS peersWithProduct
ORDER BY peersWithProduct DESC;

// 4c. Product gap analysis by segment — which products are under-represented
//     in each segment?
MATCH (c:Customer {status: 'banked'})
WITH c.segment AS segment, count(c) AS segTotal
MATCH (c2:Customer {status: 'banked', segment: segment})-[:HOLDS_PRODUCT]->(p:Product)
WITH segment, segTotal, p, count(DISTINCT c2) AS holders
RETURN segment, p.name AS product, p.pillar AS pillar,
       holders, segTotal,
       round(holders * 100.0 / segTotal, 1) AS penetrationPct
ORDER BY segment, penetrationPct ASC;


// ──────────────────────────────────────────────────────────────────────────────
// QUERY 5 — Credit / Collateral Scoring
// User Story: "As a data scientist I want to understand a customer's business
//   to enable us to do collateralised scoring on platform."
// ──────────────────────────────────────────────────────────────────────────────

// 5a. Inbound payment diversity score — count of distinct payers, total inflow,
//     channel diversity, and payment regularity as a proxy for creditworthiness
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WITH c,
     count(DISTINCT payer)    AS distinctPayers,
     sum(tw.amount)           AS totalInflowZAR,
     sum(tw.txCount)          AS totalInboundTx
MATCH (c)-[:HAS_ACCOUNT]->(a)<-[:RECEIVED_BY]-(t:Transaction)
WITH c, distinctPayers, totalInflowZAR, totalInboundTx,
     count(DISTINCT t.channel) AS channelDiversity
RETURN c.name           AS customer,
       c.segment        AS segment,
       c.riskScore      AS existingRiskScore,
       distinctPayers,
       channelDiversity,
       totalInboundTx,
       round(totalInflowZAR, 2)        AS totalInflowZAR,
       round(totalInflowZAR / totalInboundTx, 2) AS avgPaymentSize,
       CASE
         WHEN distinctPayers >= 10 AND channelDiversity >= 3 THEN 'LOW RISK'
         WHEN distinctPayers >= 5  AND channelDiversity >= 2 THEN 'MEDIUM RISK'
         ELSE 'HIGHER RISK'
       END AS collateralGrade
ORDER BY totalInflowZAR DESC
LIMIT 30;

// 5b. Revenue concentration risk — what % of a customer's inbound revenue
//     comes from their single largest payer?
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WITH c, payer, tw.amount AS payerAmount
ORDER BY payerAmount DESC
WITH c, collect({name: payer.name, amount: payerAmount}) AS payers,
     sum(payerAmount) AS totalInflow
WITH c, payers[0] AS topPayer, totalInflow
RETURN c.name AS customer,
       topPayer.name AS largestPayer,
       round(topPayer.amount, 2) AS largestPayerZAR,
       round(totalInflow, 2) AS totalInflowZAR,
       round(topPayer.amount * 100.0 / totalInflow, 1) AS concentrationPct
ORDER BY concentrationPct DESC
LIMIT 20;

// 5c. Customer stability score — customers with consistent payment patterns
//     across multiple channels and regular intervals
MATCH (payer:Customer)-[tw:TRADES_WITH]->(c:Customer {status: 'banked'})
WHERE tw.avgInterval IS NOT NULL
WITH c,
     count(DISTINCT payer)     AS payers,
     avg(tw.avgInterval)       AS avgIntervalDays,
     stDev(tw.avgInterval)     AS intervalStdDev,
     sum(tw.amount)            AS totalInflow
WHERE payers >= 3
RETURN c.name                  AS customer,
       c.segment               AS segment,
       payers,
       round(avgIntervalDays, 1)  AS avgIntervalDays,
       round(intervalStdDev, 1)   AS intervalStdDevDays,
       round(totalInflow, 2)      AS totalInflowZAR,
       CASE
         WHEN intervalStdDev < 10 THEN 'HIGHLY STABLE'
         WHEN intervalStdDev < 30 THEN 'STABLE'
         ELSE 'VARIABLE'
       END AS stabilityGrade
ORDER BY intervalStdDev ASC
LIMIT 20;
