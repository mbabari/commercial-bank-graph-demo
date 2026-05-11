// ============================================================================
// Commercial Bank Graph — Data Load Script
// Run AFTER 01_schema.cypher.
//
// IMPORTANT: Replace $BASE_URL with the public URL where your CSV files are
// hosted (e.g. a GitHub raw URL, S3 bucket, or Neo4j import directory).
// For Aura, files must be accessible via HTTPS.
//
// If loading locally, place CSVs in the Neo4j import/ directory and use
// 'file:///filename.csv' instead.
// ============================================================================

// ---------------------------------------------------------------------------
// 1. Load Industries
// ---------------------------------------------------------------------------

LOAD CSV WITH HEADERS FROM '$BASE_URL/industries.csv' AS row
CREATE (i:Industry {
  sicCode:  row.sicCode,
  name:     row.name,
  sector:   row.sector
});

// ---------------------------------------------------------------------------
// 2. Load Products
// ---------------------------------------------------------------------------

LOAD CSV WITH HEADERS FROM '$BASE_URL/products.csv' AS row
CREATE (p:Product {
  productId:  row.productId,
  name:       row.name,
  pillar:     row.pillar,
  monthlyFee: toFloat(row.monthlyFee)
});

// ---------------------------------------------------------------------------
// 3. Load Banked Customers
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/customers_banked.csv' AS row
CALL {
  WITH row
  MATCH (i:Industry {sicCode: row.sicCode})
  CREATE (c:Customer {
    customerId:         row.customerId,
    name:               row.name,
    registrationNumber: row.registrationNumber,
    region:             row.region,
    segment:            row.segment,
    status:             row.status,
    turnover:           toFloat(row.turnover),
    riskScore:          toFloat(row.riskScore)
  })
  CREATE (c)-[:BELONGS_TO]->(i)
} IN TRANSACTIONS OF 500 ROWS;

// ---------------------------------------------------------------------------
// 4. Load Unbanked Entities
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/entities_unbanked.csv' AS row
CALL {
  WITH row
  MATCH (i:Industry {sicCode: row.sicCode})
  CREATE (c:Customer {
    customerId: row.customerId,
    name:       row.name,
    region:     row.region,
    status:     row.status
  })
  CREATE (c)-[:BELONGS_TO]->(i)
} IN TRANSACTIONS OF 500 ROWS;

// ---------------------------------------------------------------------------
// 5. Load Accounts
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/accounts.csv' AS row
CALL {
  WITH row
  MATCH (c:Customer {customerId: row.customerId})
  CREATE (a:Account {
    accountId:   row.accountId,
    accountType: row.accountType,
    openDate:    date(row.openDate),
    balance:     toFloat(row.balance)
  })
  CREATE (c)-[:HAS_ACCOUNT]->(a)
} IN TRANSACTIONS OF 500 ROWS;

// ---------------------------------------------------------------------------
// 6. Load EFT Transactions
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/transactions_eft.csv' AS row
CALL {
  WITH row
  MATCH (sender:Account {accountId: row.senderAccountId})
  MATCH (receiver:Account {accountId: row.receiverAccountId})
  CREATE (t:Transaction {
    transactionId: row.transactionId,
    amount:        toFloat(row.amount),
    currency:      row.currency,
    date:          date(row.date),
    channel:       row.channel,
    reference:     row.reference
  })
  CREATE (sender)-[:SENT]->(t)
  CREATE (t)-[:RECEIVED_BY]->(receiver)
} IN TRANSACTIONS OF 1000 ROWS;

// ---------------------------------------------------------------------------
// 7. Load NAV Transactions
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/transactions_nav.csv' AS row
CALL {
  WITH row
  MATCH (sender:Account {accountId: row.senderAccountId})
  MATCH (receiver:Account {accountId: row.receiverAccountId})
  CREATE (t:Transaction {
    transactionId: row.transactionId,
    amount:        toFloat(row.amount),
    currency:      row.currency,
    date:          date(row.date),
    channel:       row.channel,
    reference:     row.reference
  })
  CREATE (sender)-[:SENT]->(t)
  CREATE (t)-[:RECEIVED_BY]->(receiver)
} IN TRANSACTIONS OF 1000 ROWS;

// ---------------------------------------------------------------------------
// 8. Load SOF Transactions
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/transactions_sof.csv' AS row
CALL {
  WITH row
  MATCH (sender:Account {accountId: row.senderAccountId})
  MATCH (receiver:Account {accountId: row.receiverAccountId})
  CREATE (t:Transaction {
    transactionId: row.transactionId,
    amount:        toFloat(row.amount),
    currency:      row.currency,
    date:          date(row.date),
    channel:       row.channel,
    reference:     row.reference
  })
  CREATE (sender)-[:SENT]->(t)
  CREATE (t)-[:RECEIVED_BY]->(receiver)
} IN TRANSACTIONS OF 1000 ROWS;

// ---------------------------------------------------------------------------
// 9. Load SWIFT Transactions
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/transactions_swift.csv' AS row
CALL {
  WITH row
  MATCH (sender:Account {accountId: row.senderAccountId})
  MATCH (receiver:Account {accountId: row.receiverAccountId})
  CREATE (t:Transaction {
    transactionId: row.transactionId,
    amount:        toFloat(row.amount),
    currency:      row.currency,
    date:          date(row.date),
    channel:       row.channel,
    reference:     row.reference
  })
  CREATE (sender)-[:SENT]->(t)
  CREATE (t)-[:RECEIVED_BY]->(receiver)
} IN TRANSACTIONS OF 500 ROWS;

// ---------------------------------------------------------------------------
// 10. Load Product Holdings
// ---------------------------------------------------------------------------

:auto
LOAD CSV WITH HEADERS FROM '$BASE_URL/product_holdings.csv' AS row
CALL {
  WITH row
  MATCH (c:Customer {customerId: row.customerId})
  MATCH (p:Product {productId: row.productId})
  CREATE (c)-[:HOLDS_PRODUCT {since: date(row.since)}]->(p)
} IN TRANSACTIONS OF 500 ROWS;

// ---------------------------------------------------------------------------
// 11. Create aggregated TRADES_WITH relationships
//     Materialises a direct Customer-to-Customer edge summarising all
//     transactions between them (via their accounts).
// ---------------------------------------------------------------------------

:auto
MATCH (sender:Customer)-[:HAS_ACCOUNT]->(sa:Account)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->(ra:Account)<-[:HAS_ACCOUNT]-(receiver:Customer)
WHERE sender <> receiver
WITH sender, receiver, sum(t.amount) AS totalAmount, count(t) AS txCount
CALL {
  WITH sender, receiver, totalAmount, txCount
  MERGE (sender)-[r:TRADES_WITH]->(receiver)
  ON CREATE SET r.amount = totalAmount, r.txCount = txCount
  ON MATCH  SET r.amount = r.amount + totalAmount, r.txCount = r.txCount + txCount
} IN TRANSACTIONS OF 1000 ROWS;

// ---------------------------------------------------------------------------
// 12. Compute average payment interval on TRADES_WITH
// ---------------------------------------------------------------------------

MATCH (s:Customer)-[:HAS_ACCOUNT]->(sa)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->(ra)<-[:HAS_ACCOUNT]-(r:Customer)
WHERE s <> r
WITH s, r, t ORDER BY t.date
WITH s, r, collect(t.date) AS dates
WHERE size(dates) > 1
WITH s, r,
     reduce(total = 0,
            idx IN range(1, size(dates)-1) |
            total + duration.between(dates[idx-1], dates[idx]).days
     ) / (size(dates)-1) AS avgDays
MATCH (s)-[tw:TRADES_WITH]->(r)
SET tw.avgInterval = avgDays;

// ---------------------------------------------------------------------------
// Verification counts
// ---------------------------------------------------------------------------

MATCH (n) RETURN labels(n)[0] AS label, count(*) AS count ORDER BY label;
MATCH ()-[r]->() RETURN type(r) AS relType, count(*) AS count ORDER BY relType;
