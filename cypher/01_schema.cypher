// ============================================================================
// Commercial Bank Graph — Schema: Constraints & Indexes
// Run this FIRST before loading any data.
// ============================================================================

// --- Uniqueness constraints (implicitly create indexes) ---

CREATE CONSTRAINT customer_id IF NOT EXISTS
FOR (c:Customer) REQUIRE c.customerId IS UNIQUE;

CREATE CONSTRAINT account_id IF NOT EXISTS
FOR (a:Account) REQUIRE a.accountId IS UNIQUE;

CREATE CONSTRAINT transaction_id IF NOT EXISTS
FOR (t:Transaction) REQUIRE t.transactionId IS UNIQUE;

CREATE CONSTRAINT industry_sic IF NOT EXISTS
FOR (i:Industry) REQUIRE i.sicCode IS UNIQUE;

CREATE CONSTRAINT product_id IF NOT EXISTS
FOR (p:Product) REQUIRE p.productId IS UNIQUE;

// --- Additional indexes for query performance ---

CREATE INDEX customer_status IF NOT EXISTS
FOR (c:Customer) ON (c.status);

CREATE INDEX customer_region IF NOT EXISTS
FOR (c:Customer) ON (c.region);

CREATE INDEX customer_segment IF NOT EXISTS
FOR (c:Customer) ON (c.segment);

CREATE INDEX transaction_channel IF NOT EXISTS
FOR (t:Transaction) ON (t.channel);

CREATE INDEX transaction_date IF NOT EXISTS
FOR (t:Transaction) ON (t.date);

CREATE INDEX industry_sector IF NOT EXISTS
FOR (i:Industry) ON (i.sector);

CREATE INDEX product_pillar IF NOT EXISTS
FOR (p:Product) ON (p.pillar);

// --- Fulltext index for entity resolution (fuzzy name matching) ---

CREATE FULLTEXT INDEX customer_name_fulltext IF NOT EXISTS
FOR (c:Customer) ON EACH [c.name];
