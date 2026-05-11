# Publishing this repository for customers

This tree is a **sanitised** copy of the Commercial Bank Graph demo: synthetic data only, no institution-specific names, and **no credentials** in the repository.

## Repositories on GitHub

These repos are published under **mbabari** as public repositories. If you fork them, update clone and raw URLs in `README.md` and workshop docs to match your fork.

1. **Do not** commit `.env`, `.env.local`, or any Aura passwords. Use `.env.example` patterns only in documentation.

The public **commercial-bank-graph-demo** tree intentionally omits a `presentation/` folder (slides and long-form workshop scripts are kept out of this repo).

Long-form ER positioning documents (`explore/entity_resolution.md`, `explore/er_customer360.md`, `explore/er_industry_agnostic.md`) are also omitted from this repo; Explore setup and walkthrough remain in `explore/bloom_setup.md` and `explore/explore_story.md`.

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
