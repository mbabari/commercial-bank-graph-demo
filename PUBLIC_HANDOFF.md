# Publishing this repository for customers

This tree is a **sanitised** copy of the Commercial Bank Graph demo: synthetic data only, no institution-specific names, and **no credentials** in the repository.

## Repositories on GitHub

These repos are published under **mbabari** as public repositories. If you fork them, update clone and raw URLs in `README.md` and workshop docs to match your fork.

1. **Do not** commit `.env`, `.env.local`, or any Aura passwords. Use `.env.example` patterns only in documentation.

2. **Optional:** Remove the `presentation/` folder if you only want to ship data + Cypher + explore guides.

## Data loader (`neo4j-mcp-server/load_demo.mjs`)

Connection settings must be passed via environment variables:

```bash
export NEO4J_URI='neo4j+s://xxxx.databases.neo4j.io'
export NEO4J_USERNAME='neo4j'
export NEO4J_PASSWORD='<your-password>'
export NEO4J_DATABASE='neo4j'
node neo4j-mcp-server/load_demo.mjs
```

## GDS graph name

Cypher in `cypher/04_gds_algorithms.cypher` uses the in-memory graph id **`commercial-bank-graph`**. If you rename it, update every `gds.*` call that references that id.
