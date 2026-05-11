#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import neo4j, { Driver, Session } from "neo4j-driver";
import { z } from "zod";

const NEO4J_URI = process.env.NEO4J_URI!;
const NEO4J_USERNAME = process.env.NEO4J_USERNAME || "neo4j";
const NEO4J_PASSWORD = process.env.NEO4J_PASSWORD!;
const NEO4J_DATABASE = process.env.NEO4J_DATABASE || "neo4j";

let driver: Driver;

function getDriver(): Driver {
  if (!driver) {
    driver = neo4j.driver(NEO4J_URI, neo4j.auth.basic(NEO4J_USERNAME, NEO4J_PASSWORD));
  }
  return driver;
}

function getSession(): Session {
  return getDriver().session({ database: NEO4J_DATABASE });
}

function serializeNeo4jValue(value: unknown): unknown {
  if (value === null || value === undefined) return value;
  if (neo4j.isInt(value)) return (value as neo4j.Integer).toNumber();
  if (neo4j.isDate(value) || neo4j.isDateTime(value) || neo4j.isLocalDateTime(value) ||
      neo4j.isTime(value) || neo4j.isLocalTime(value) || neo4j.isDuration(value)) {
    return value.toString();
  }
  if (Array.isArray(value)) return value.map(serializeNeo4jValue);
  if (typeof value === "object" && value !== null) {
    const result: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      result[k] = serializeNeo4jValue(v);
    }
    return result;
  }
  return value;
}

async function runQuery(cypher: string, params: Record<string, unknown> = {}): Promise<string> {
  const session = getSession();
  try {
    const result = await session.run(cypher, params);
    const records = result.records.map((record) => {
      const obj: Record<string, unknown> = {};
      for (const key of record.keys) {
        obj[String(key)] = serializeNeo4jValue(record.get(key as string));
      }
      return obj;
    });

    const summary = result.summary;
    const counters = summary.counters.updates();
    const hasUpdates = Object.values(counters).some((v) => v > 0);

    let output = "";
    if (records.length > 0) {
      output += JSON.stringify(records, null, 2);
    }
    if (hasUpdates) {
      output += (output ? "\n\n" : "") + "Updates: " + JSON.stringify(counters);
    }
    if (!output) {
      output = "Query executed successfully. No results returned.";
    }

    output += `\n\n(${records.length} record(s), ${summary.resultAvailableAfter?.toNumber() ?? 0}ms)`;
    return output;
  } finally {
    await session.close();
  }
}

const server = new McpServer({
  name: "neo4j-aura",
  version: "1.0.0",
});

server.tool(
  "cypher_query",
  "Execute a read-only Cypher query against the Neo4j database. Use MATCH, RETURN, WITH, WHERE, etc. Do NOT use CREATE, MERGE, DELETE, SET, or REMOVE.",
  {
    query: z.string().describe("The Cypher query to execute (read-only)"),
    params: z.record(z.unknown()).optional().describe("Optional query parameters as key-value pairs"),
  },
  async ({ query, params }) => {
    const forbidden = /\b(CREATE|MERGE|DELETE|DETACH|SET|REMOVE|DROP|CALL\s+\{)\b/i;
    if (forbidden.test(query)) {
      return {
        content: [{ type: "text", text: "Error: Write operations are not allowed via this tool. Use cypher_write for mutations." }],
        isError: true,
      };
    }
    try {
      const result = await runQuery(query, params ?? {});
      return { content: [{ type: "text", text: result }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Query error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "cypher_write",
  "Execute a write Cypher query (CREATE, MERGE, DELETE, SET, etc.). Use with caution.",
  {
    query: z.string().describe("The Cypher write query to execute"),
    params: z.record(z.unknown()).optional().describe("Optional query parameters"),
  },
  async ({ query, params }) => {
    try {
      const result = await runQuery(query, params ?? {});
      return { content: [{ type: "text", text: result }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Write error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_schema",
  "Get the full database schema: node labels, relationship types, property keys, constraints, and indexes.",
  {},
  async () => {
    try {
      const parts: string[] = [];

      const labels = await runQuery("CALL db.labels() YIELD label RETURN label ORDER BY label");
      parts.push("=== Node Labels ===\n" + labels);

      const relTypes = await runQuery("CALL db.relationshipTypes() YIELD relationshipType RETURN relationshipType ORDER BY relationshipType");
      parts.push("=== Relationship Types ===\n" + relTypes);

      const props = await runQuery("CALL db.propertyKeys() YIELD propertyKey RETURN propertyKey ORDER BY propertyKey");
      parts.push("=== Property Keys ===\n" + props);

      try {
        const constraints = await runQuery("SHOW CONSTRAINTS");
        parts.push("=== Constraints ===\n" + constraints);
      } catch {
        parts.push("=== Constraints ===\n(Not available)");
      }

      try {
        const indexes = await runQuery("SHOW INDEXES");
        parts.push("=== Indexes ===\n" + indexes);
      } catch {
        parts.push("=== Indexes ===\n(Not available)");
      }

      return { content: [{ type: "text", text: parts.join("\n\n") }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Schema error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_node_counts",
  "Get the count of nodes for each label in the database.",
  {},
  async () => {
    try {
      const result = await runQuery(`
        CALL db.labels() YIELD label
        CALL apoc.cypher.run('MATCH (n:\`' + label + '\`) RETURN count(n) AS count', {}) YIELD value
        RETURN label, value.count AS count
        ORDER BY count DESC
      `);
      return { content: [{ type: "text", text: result }] };
    } catch {
      try {
        const labels = await runQuery("CALL db.labels() YIELD label RETURN label");
        const parsed = JSON.parse(labels.split("\n\n")[0]);
        const counts: string[] = [];
        for (const row of parsed) {
          const countResult = await runQuery(`MATCH (n:\`${row.label}\`) RETURN count(n) AS count`);
          const countParsed = JSON.parse(countResult.split("\n\n")[0]);
          counts.push(`${row.label}: ${countParsed[0]?.count ?? 0}`);
        }
        return { content: [{ type: "text", text: "Node counts by label:\n" + counts.join("\n") }] };
      } catch (error) {
        return {
          content: [{ type: "text", text: `Error: ${(error as Error).message}` }],
          isError: true,
        };
      }
    }
  }
);

server.tool(
  "get_sample_nodes",
  "Get sample nodes for a given label, showing their properties.",
  {
    label: z.string().describe("The node label to sample"),
    limit: z.number().optional().default(5).describe("Number of sample nodes to return (default 5)"),
  },
  async ({ label, limit }) => {
    try {
      const result = await runQuery(
        `MATCH (n:\`${label}\`) RETURN n LIMIT $limit`,
        { limit: neo4j.int(limit ?? 5) }
      );
      return { content: [{ type: "text", text: result }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_relationships",
  "Get sample relationships between nodes, optionally filtered by type.",
  {
    type: z.string().optional().describe("Relationship type to filter (optional)"),
    limit: z.number().optional().default(10).describe("Number of relationships to return (default 10)"),
  },
  async ({ type, limit }) => {
    try {
      const cypher = type
        ? `MATCH (a)-[r:\`${type}\`]->(b) RETURN labels(a) AS from_labels, properties(r) AS rel_props, type(r) AS rel_type, labels(b) AS to_labels LIMIT $limit`
        : `MATCH (a)-[r]->(b) RETURN labels(a) AS from_labels, properties(r) AS rel_props, type(r) AS rel_type, labels(b) AS to_labels LIMIT $limit`;
      const result = await runQuery(cypher, { limit: neo4j.int(limit ?? 10) });
      return { content: [{ type: "text", text: result }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

server.tool(
  "get_graph_summary",
  "Get a high-level summary of the graph: total nodes, relationships, labels, and relationship types with counts.",
  {},
  async () => {
    try {
      const parts: string[] = [];

      const totalNodes = await runQuery("MATCH (n) RETURN count(n) AS totalNodes");
      parts.push("Total nodes: " + JSON.parse(totalNodes.split("\n\n")[0])[0]?.totalNodes);

      const totalRels = await runQuery("MATCH ()-[r]->() RETURN count(r) AS totalRelationships");
      parts.push("Total relationships: " + JSON.parse(totalRels.split("\n\n")[0])[0]?.totalRelationships);

      const labelCounts = await runQuery(`
        MATCH (n) 
        WITH labels(n) AS lbls 
        UNWIND lbls AS label 
        RETURN label, count(*) AS count 
        ORDER BY count DESC
      `);
      parts.push("Node labels:\n" + labelCounts.split("\n\n")[0]);

      const relCounts = await runQuery(`
        MATCH ()-[r]->() 
        RETURN type(r) AS type, count(*) AS count 
        ORDER BY count DESC
      `);
      parts.push("Relationship types:\n" + relCounts.split("\n\n")[0]);

      return { content: [{ type: "text", text: parts.join("\n\n") }] };
    } catch (error) {
      return {
        content: [{ type: "text", text: `Error: ${(error as Error).message}` }],
        isError: true,
      };
    }
  }
);

async function main() {
  if (!NEO4J_URI || !NEO4J_PASSWORD) {
    console.error("Missing required environment variables: NEO4J_URI, NEO4J_PASSWORD");
    process.exit(1);
  }

  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error(`Neo4j MCP Server running - connected to ${NEO4J_URI}`);
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});

process.on("SIGINT", async () => {
  if (driver) await driver.close();
  process.exit(0);
});
