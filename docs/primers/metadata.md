# Metadata, Lineage, and Data Catalogs

## What metadata is

In this project, "metadata" has appeared in three places so far:

1. **Parquet file headers** — column names, types, row counts, statistics
2. **targets hashes** — function code + data hashes determining freshness
3. **Git commits** — who changed what, when, and why

These are all **metadata**: data about data. The actual eviction records
are data. The schema, the hashes, the commit history — those are metadata.

## Why metadata matters at scale

At the scale of this learning project, metadata management is informal.
You know what files exist because you created them. You know the schema
because you wrote the code.

At organizational scale, metadata becomes critical:
- Which table was last updated? (Freshness)
- What code produced this dataset? (Lineage)
- What columns does it have and what do they mean? (Schema/documentation)
- Is anyone still using this table? (Usage)
- Has the schema changed since last month? (Evolution)

## Data lineage

**Lineage** answers: "where did this data come from?"

In this project, the lineage is simple and traceable:

```
Oklahoma Court Records (ojodb)
    ↓ exported by targets project
CSV file (data/raw/evictions_*.csv)
    ↓ load_eviction_data()
R tibble (raw_data)
    ↓ convert_csv_to_parquet()
Parquet (data/parquet/evictions.parquet)
    ↓ summarize_annual() / query_evictions_duckdb()
Summary tables
    ↓ Quarto render
HTML report pages
```

The targets DAG IS the lineage — each edge in the graph traces data flow
from source to output. `targets::tar_visnetwork()` is a lineage viewer.

## Where metadata lives in lakehouse systems

This project uses ad-hoc metadata (files, hashes, git history). Production
systems use **metadata catalogs**:

| System | Metadata approach |
|---|---|
| **Apache Iceberg** | Metadata stored alongside data in cloud storage; tracks schema, partitions, snapshots |
| **Delta Lake** | Transaction log tracks every change as a JSON entry |
| **DuckLake** | Stores metadata in a DuckDB database (newest approach) |
| **Hive Metastore** | Central MySQL/Postgres database storing schema + location |

### What these systems add

- **Schema evolution:** Add/rename columns without breaking readers
- **Time travel:** Query data as it existed at a specific point in time
- **Partition management:** Metadata tracks which files belong to which partitions
- **ACID transactions:** Concurrent reads and writes don't corrupt data

### The partitioning note

The starter prompt says: "Partitioning is an optimization, not a feature.
Don't implement it." This is correct for our dataset (~27K rows). Partitioning
matters when:
- The dataset has millions+ rows
- Queries consistently filter on a specific column (like `filing_year`)
- You want to avoid reading the entire dataset for filtered queries

At our scale, Arrow reads the whole parquet file faster than the overhead
of partition management.

## What you'd build next (if going further)

1. **A `manifest.yaml` per dataset** — documenting schema, source, freshness,
   and responsible team
2. **A lineage tracking system** — tracing data from source through
   transformations to reports (targets does this implicitly)
3. **Schema validation on ingest** — `pointblank` checks that incoming data
   matches expected types and ranges
4. **A data catalog** — a searchable index of all datasets, their schemas,
   and their lineage (tools: DataHub, Amundsen, or just a Quarto page)
