// ============================================================================
// Commercial Bank Graph — GDS Algorithm Projections & Execution
// Run AFTER data load (02_load_data.cypher).
//
// These algorithms enrich Customer nodes with graph-derived properties that
// are then visible in Explore UI for visual analytics.
//
// Requires: Neo4j GDS plugin (included in Aura Professional / Enterprise).
// ============================================================================


// ──────────────────────────────────────────────────────────────────────────────
// STEP 0 — Create a Graph Projection
// Projects Customer nodes and TRADES_WITH relationships into an in-memory
// graph for algorithm execution.
// ──────────────────────────────────────────────────────────────────────────────

// Drop existing projection if re-running
CALL gds.graph.drop('commercial-bank-graph', false);

// Create the projection with relationship weight
CALL gds.graph.project(
  'commercial-bank-graph',
  'Customer',
  {
    TRADES_WITH: {
      type: 'TRADES_WITH',
      orientation: 'UNDIRECTED',
      properties: {
        amount: { property: 'amount', defaultValue: 0.0 },
        txCount: { property: 'txCount', defaultValue: 1 }
      }
    }
  }
);

// Verify projection
CALL gds.graph.list()
YIELD graphName, nodeCount, relationshipCount
RETURN graphName, nodeCount, relationshipCount;


// ──────────────────────────────────────────────────────────────────────────────
// ALGORITHM 1 — PageRank
// Identifies the most influential entities in the payment network.
// High PageRank = entity that receives payments from other high-PageRank
// entities. Useful for finding high-value unbanked conversion targets.
// ──────────────────────────────────────────────────────────────────────────────

// Estimate memory
CALL gds.pageRank.write.estimate('commercial-bank-graph', {
  writeProperty: 'pageRank',
  relationshipWeightProperty: 'amount'
})
YIELD requiredMemory, nodeCount, relationshipCount;

// Run and write back
CALL gds.pageRank.write('commercial-bank-graph', {
  writeProperty: 'pageRank',
  relationshipWeightProperty: 'amount',
  maxIterations: 20,
  dampingFactor: 0.85
})
YIELD nodePropertiesWritten, ranIterations, didConverge,
      centralityDistribution;

// Top 15 entities by PageRank
MATCH (c:Customer)
WHERE c.pageRank IS NOT NULL
RETURN c.name AS entity, c.status AS status, c.region AS region,
       round(c.pageRank, 6) AS pageRank
ORDER BY c.pageRank DESC
LIMIT 15;

// Top unbanked entities by PageRank (conversion priority list)
MATCH (c:Customer {status: 'unbanked'})
WHERE c.pageRank IS NOT NULL
RETURN c.name AS entity, c.region AS region,
       round(c.pageRank, 6) AS pageRank
ORDER BY c.pageRank DESC
LIMIT 10;


// ──────────────────────────────────────────────────────────────────────────────
// ALGORITHM 2 — Community Detection (Louvain)
// Finds clusters of companies that trade heavily with each other.
// Each community represents an industry ecosystem or supply chain cluster.
// ──────────────────────────────────────────────────────────────────────────────

// Estimate memory
CALL gds.louvain.write.estimate('commercial-bank-graph', {
  writeProperty: 'communityId',
  relationshipWeightProperty: 'amount'
})
YIELD requiredMemory;

// Run and write back
CALL gds.louvain.write('commercial-bank-graph', {
  writeProperty: 'communityId',
  relationshipWeightProperty: 'amount'
})
YIELD communityCount, modularity, modularities;

// Community summary — size, banked/unbanked mix, dominant industry
MATCH (c:Customer)
WHERE c.communityId IS NOT NULL
WITH c.communityId AS community, c
WITH community,
     count(c) AS size,
     count(CASE WHEN c.status = 'banked' THEN 1 END) AS banked,
     count(CASE WHEN c.status = 'unbanked' THEN 1 END) AS unbanked
ORDER BY size DESC
RETURN community, size, banked, unbanked,
       round(unbanked * 100.0 / size, 1) AS unbankedPct
LIMIT 15;

// Dominant industry per community
MATCH (c:Customer)-[:BELONGS_TO]->(i:Industry)
WHERE c.communityId IS NOT NULL
WITH c.communityId AS community, i.sector AS sector, count(*) AS cnt
ORDER BY community, cnt DESC
WITH community, collect({sector: sector, count: cnt})[0] AS top
RETURN community, top.sector AS dominantSector, top.count AS entityCount
ORDER BY entityCount DESC
LIMIT 15;


// ──────────────────────────────────────────────────────────────────────────────
// ALGORITHM 3 — Betweenness Centrality
// Finds broker entities that bridge multiple communities.
// High betweenness = entity that sits on many shortest paths between others,
// making it a key connector and potential systemic risk.
// ──────────────────────────────────────────────────────────────────────────────

// Estimate memory
CALL gds.betweenness.write.estimate('commercial-bank-graph', {
  writeProperty: 'betweenness'
})
YIELD requiredMemory;

// Run and write back
CALL gds.betweenness.write('commercial-bank-graph', {
  writeProperty: 'betweenness'
})
YIELD nodePropertiesWritten, centralityDistribution;

// Top 15 broker entities
MATCH (c:Customer)
WHERE c.betweenness IS NOT NULL
RETURN c.name AS entity, c.status AS status,
       c.communityId AS community,
       round(c.betweenness, 2) AS betweenness,
       round(c.pageRank, 6) AS pageRank
ORDER BY c.betweenness DESC
LIMIT 15;

// Broker entities that bridge 2+ communities
MATCH (c:Customer)-[:TRADES_WITH]-(other:Customer)
WHERE c.betweenness IS NOT NULL AND other.communityId IS NOT NULL
      AND c.communityId IS NOT NULL
WITH c, collect(DISTINCT other.communityId) AS connectedCommunities
WHERE size(connectedCommunities) >= 2
RETURN c.name AS entity, c.status AS status,
       c.communityId AS ownCommunity,
       connectedCommunities,
       size(connectedCommunities) AS communitiesBridged,
       round(c.betweenness, 2) AS betweenness
ORDER BY communitiesBridged DESC, c.betweenness DESC
LIMIT 15;


// ──────────────────────────────────────────────────────────────────────────────
// ALGORITHM 4 — Node Similarity
// Finds customers with similar trading patterns.
// Uses Jaccard similarity on the set of counterparties each customer trades
// with. Useful for peer-based product recommendations and credit benchmarking.
// ──────────────────────────────────────────────────────────────────────────────

// Run Node Similarity and write results as SIMILAR_TO relationships
CALL gds.nodeSimilarity.write('commercial-bank-graph', {
  writeRelationshipType: 'SIMILAR_TO',
  writeProperty: 'similarity',
  similarityCutoff: 0.3,
  topK: 5
})
YIELD nodesCompared, relationshipsWritten, similarityDistribution;

// Top similar pairs
MATCH (a:Customer)-[s:SIMILAR_TO]->(b:Customer)
WHERE a.status = 'banked' AND b.status = 'banked'
RETURN a.name AS customer1, a.segment AS segment1,
       b.name AS customer2, b.segment AS segment2,
       round(s.similarity, 3) AS similarity
ORDER BY s.similarity DESC
LIMIT 20;

// For a specific customer, find their most similar peers and compare products
MATCH (target:Customer {customerId: 'CUST-00001'})-[s:SIMILAR_TO]-(peer:Customer)
OPTIONAL MATCH (target)-[:HOLDS_PRODUCT]->(tp:Product)
OPTIONAL MATCH (peer)-[:HOLDS_PRODUCT]->(pp:Product)
WITH target, peer, s.similarity AS sim,
     collect(DISTINCT tp.name) AS targetProducts,
     collect(DISTINCT pp.name) AS peerProducts
RETURN peer.name AS similarPeer,
       round(sim, 3) AS similarity,
       targetProducts,
       peerProducts,
       [p IN peerProducts WHERE NOT p IN targetProducts] AS recommendedProducts
ORDER BY sim DESC;


// ──────────────────────────────────────────────────────────────────────────────
// CLEANUP — Drop the in-memory graph when done
// (Uncomment if you want to free memory after running all algorithms)
// ──────────────────────────────────────────────────────────────────────────────

// CALL gds.graph.drop('commercial-bank-graph');
