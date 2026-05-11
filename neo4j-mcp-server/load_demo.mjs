#!/usr/bin/env node
/**
 * Loads the full Commercial Bank Graph demo into Neo4j Aura
 * by reading local CSV files and executing parameterized Cypher.
 * Credentials must be supplied via environment variables — never commit secrets.
 */

import neo4j from "neo4j-driver";
import { readFileSync } from "fs";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const DATA_DIR = join(__dirname, "..", "data");

const URI = process.env.NEO4J_URI;
const USER = process.env.NEO4J_USERNAME || "neo4j";
const PASS = process.env.NEO4J_PASSWORD;
const DB = process.env.NEO4J_DATABASE || "neo4j";

if (!URI || !PASS) {
  console.error(
    "Missing NEO4J_URI or NEO4J_PASSWORD. Example:\n" +
      "  export NEO4J_URI='neo4j+s://xxxx.databases.neo4j.io'\n" +
      "  export NEO4J_PASSWORD='your-aura-password'\n" +
      "  node neo4j-mcp-server/load_demo.mjs"
  );
  process.exit(1);
}

const driver = neo4j.driver(URI, neo4j.auth.basic(USER, PASS));

function readCSV(filename) {
  const raw = readFileSync(join(DATA_DIR, filename), "utf-8");
  const lines = raw.trim().split("\n");
  const headers = lines[0].split(",");
  return lines.slice(1).map((line) => {
    const values = [];
    let current = "";
    let inQuotes = false;
    for (const char of line) {
      if (char === '"') {
        inQuotes = !inQuotes;
      } else if (char === "," && !inQuotes) {
        values.push(current);
        current = "";
      } else {
        current += char;
      }
    }
    values.push(current);
    const obj = {};
    headers.forEach((h, i) => {
      obj[h.trim()] = (values[i] || "").trim();
    });
    return obj;
  });
}

async function run(cypher, params = {}) {
  const session = driver.session({ database: DB });
  try {
    const result = await session.run(cypher, params);
    return result;
  } finally {
    await session.close();
  }
}

async function runBatch(cypher, rows, batchSize = 500) {
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize);
    await run(cypher, { batch });
  }
}

function elapsed(start) {
  return ((Date.now() - start) / 1000).toFixed(1);
}

async function main() {
  const t0 = Date.now();
  console.log("=== Commercial Bank Graph — Full Data Load ===\n");

  // ─── Step 1: Schema ───
  console.log("[1/9] Creating constraints and indexes...");
  const schemaStatements = [
    "CREATE CONSTRAINT customer_id IF NOT EXISTS FOR (c:Customer) REQUIRE c.customerId IS UNIQUE",
    "CREATE CONSTRAINT account_id IF NOT EXISTS FOR (a:Account) REQUIRE a.accountId IS UNIQUE",
    "CREATE CONSTRAINT transaction_id IF NOT EXISTS FOR (t:Transaction) REQUIRE t.transactionId IS UNIQUE",
    "CREATE CONSTRAINT industry_sic IF NOT EXISTS FOR (i:Industry) REQUIRE i.sicCode IS UNIQUE",
    "CREATE CONSTRAINT product_id IF NOT EXISTS FOR (p:Product) REQUIRE p.productId IS UNIQUE",
    "CREATE INDEX customer_status IF NOT EXISTS FOR (c:Customer) ON (c.status)",
    "CREATE INDEX customer_region IF NOT EXISTS FOR (c:Customer) ON (c.region)",
    "CREATE INDEX customer_segment IF NOT EXISTS FOR (c:Customer) ON (c.segment)",
    "CREATE INDEX transaction_channel IF NOT EXISTS FOR (t:Transaction) ON (t.channel)",
    "CREATE INDEX transaction_date IF NOT EXISTS FOR (t:Transaction) ON (t.date)",
    "CREATE INDEX industry_sector IF NOT EXISTS FOR (i:Industry) ON (i.sector)",
    "CREATE INDEX product_pillar IF NOT EXISTS FOR (p:Product) ON (p.pillar)",
  ];
  for (const stmt of schemaStatements) {
    await run(stmt);
  }
  console.log(`   Done (${elapsed(t0)}s)\n`);

  // ─── Step 2: Industries ───
  console.log("[2/9] Loading industries...");
  const industries = readCSV("industries.csv");
  await runBatch(
    `UNWIND $batch AS row
     MERGE (i:Industry {sicCode: row.sicCode})
     SET i.name = row.name, i.sector = row.sector`,
    industries
  );
  console.log(`   ${industries.length} industries (${elapsed(t0)}s)\n`);

  // ─── Step 3: Products ───
  console.log("[3/9] Loading products...");
  const products = readCSV("products.csv");
  await runBatch(
    `UNWIND $batch AS row
     MERGE (p:Product {productId: row.productId})
     SET p.name = row.name, p.pillar = row.pillar, p.monthlyFee = toFloat(row.monthlyFee)`,
    products
  );
  console.log(`   ${products.length} products (${elapsed(t0)}s)\n`);

  // ─── Step 4: Banked Customers ───
  console.log("[4/9] Loading banked customers...");
  const banked = readCSV("customers_banked.csv");
  await runBatch(
    `UNWIND $batch AS row
     MATCH (i:Industry {sicCode: row.sicCode})
     MERGE (c:Customer {customerId: row.customerId})
     SET c.name = row.name,
         c.registrationNumber = row.registrationNumber,
         c.region = row.region,
         c.segment = row.segment,
         c.status = row.status,
         c.turnover = toFloat(row.turnover),
         c.riskScore = toFloat(row.riskScore)
     MERGE (c)-[:BELONGS_TO]->(i)`,
    banked
  );
  console.log(`   ${banked.length} banked customers (${elapsed(t0)}s)\n`);

  // ─── Step 5: Unbanked Entities ───
  console.log("[5/9] Loading unbanked entities...");
  const unbanked = readCSV("entities_unbanked.csv");
  await runBatch(
    `UNWIND $batch AS row
     MATCH (i:Industry {sicCode: row.sicCode})
     MERGE (c:Customer {customerId: row.customerId})
     SET c.name = row.name,
         c.region = row.region,
         c.status = row.status
     MERGE (c)-[:BELONGS_TO]->(i)`,
    unbanked
  );
  console.log(`   ${unbanked.length} unbanked entities (${elapsed(t0)}s)\n`);

  // ─── Step 6: Accounts ───
  console.log("[6/9] Loading accounts...");
  const accounts = readCSV("accounts.csv");
  await runBatch(
    `UNWIND $batch AS row
     MATCH (c:Customer {customerId: row.customerId})
     MERGE (a:Account {accountId: row.accountId})
     SET a.accountType = row.accountType,
         a.openDate = date(row.openDate),
         a.balance = toFloat(row.balance)
     MERGE (c)-[:HAS_ACCOUNT]->(a)`,
    accounts
  );
  console.log(`   ${accounts.length} accounts (${elapsed(t0)}s)\n`);

  // ─── Step 7: Transactions ───
  console.log("[7/9] Loading transactions...");
  const txCypher = `UNWIND $batch AS row
     MATCH (sender:Account {accountId: row.senderAccountId})
     MATCH (receiver:Account {accountId: row.receiverAccountId})
     CREATE (t:Transaction {
       transactionId: row.transactionId,
       amount: toFloat(row.amount),
       currency: row.currency,
       date: date(row.date),
       channel: row.channel,
       reference: row.reference
     })
     CREATE (sender)-[:SENT]->(t)
     CREATE (t)-[:RECEIVED_BY]->(receiver)`;

  for (const [file, label] of [
    ["transactions_eft.csv", "EFT"],
    ["transactions_nav.csv", "NAV"],
    ["transactions_sof.csv", "SOF"],
    ["transactions_swift.csv", "SWIFT"],
  ]) {
    const txRows = readCSV(file);
    console.log(`   Loading ${txRows.length} ${label} transactions...`);
    await runBatch(txCypher, txRows, 500);
    console.log(`   ${label} done (${elapsed(t0)}s)`);
  }
  console.log();

  // ─── Step 8: Product Holdings ───
  console.log("[8/9] Loading product holdings...");
  const holdings = readCSV("product_holdings.csv");
  await runBatch(
    `UNWIND $batch AS row
     MATCH (c:Customer {customerId: row.customerId})
     MATCH (p:Product {productId: row.productId})
     MERGE (c)-[h:HOLDS_PRODUCT]->(p)
     SET h.since = date(row.since)`,
    holdings
  );
  console.log(`   ${holdings.length} product holdings (${elapsed(t0)}s)\n`);

  // ─── Step 9: TRADES_WITH aggregation ───
  console.log("[9/9] Creating TRADES_WITH aggregated edges...");
  await run(`
    MATCH (sender:Customer)-[:HAS_ACCOUNT]->(sa:Account)-[:SENT]->(t:Transaction)-[:RECEIVED_BY]->(ra:Account)<-[:HAS_ACCOUNT]-(receiver:Customer)
    WHERE sender <> receiver
    WITH sender, receiver, sum(t.amount) AS totalAmount, count(t) AS txCount
    MERGE (sender)-[r:TRADES_WITH]->(receiver)
    ON CREATE SET r.amount = totalAmount, r.txCount = txCount
    ON MATCH  SET r.amount = r.amount + totalAmount, r.txCount = r.txCount + txCount
  `);
  console.log(`   TRADES_WITH edges created (${elapsed(t0)}s)`);

  console.log("   Computing average payment intervals...");
  await run(`
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
    SET tw.avgInterval = avgDays
  `);
  console.log(`   Done (${elapsed(t0)}s)\n`);

  // ─── Verification ───
  console.log("=== Verification ===");
  const nodeResult = await run("MATCH (n) RETURN labels(n)[0] AS label, count(*) AS count ORDER BY label");
  for (const rec of nodeResult.records) {
    console.log(`   ${rec.get("label")}: ${rec.get("count").toNumber()}`);
  }
  const relResult = await run("MATCH ()-[r]->() RETURN type(r) AS relType, count(*) AS count ORDER BY relType");
  for (const rec of relResult.records) {
    console.log(`   ${rec.get("relType")}: ${rec.get("count").toNumber()}`);
  }

  console.log(`\n=== Complete! Total time: ${elapsed(t0)}s ===`);
  await driver.close();
}

main().catch((err) => {
  console.error("FATAL:", err);
  driver.close().then(() => process.exit(1));
});
