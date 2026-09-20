# Integration Environment

Local Docker Compose environment for the diploma workspace. It deploys the systems but does not merge their source code or database ownership.

## Prerequisites

- Docker Desktop with Docker Compose v2.
- Bash/WSL or `make` for the convenience commands; PowerShell users can run `docker compose` directly.

## Repository layout

The Compose build contexts expect these repositories to be siblings:

```text
diploma/
├── integration-platform/
├── demo-business-systems/
├── warehouse-1c/
└── integration-environment/
```

`diploma/` itself must not be a Git repository.

## Start

```sh
cp .env.example .env
# Set non-empty local-only passwords for POSTGRES_PASSWORD,
# INTEGRATION_DB_PASSWORD, SHOP_DB_PASSWORD, and CRM_DB_PASSWORD in .env.
make up
# or: docker compose up --build -d
```

Integration API applies the shared platform migration while starting; Mini Shop and CRM apply their own migrations. Delivery Service shares `integration_db` with Integration API and therefore does not execute the same migration concurrently. PostgreSQL initialization creates separate databases `integration_db`, `shop_db`, and `crm_db`; there are no cross-database business queries.

## Commands

```sh
make build    # build service images
make logs     # follow logs
make down     # stop containers, preserve volumes
make reset    # remove volumes and start a clean environment
make test     # run platform, Mini Shop, and CRM pytest suites
```

Equivalent shell scripts are available in `scripts/`.

## Service URLs

| Service | URL |
| --- | --- |
| Integration API | http://localhost:8000/health/live |
| Delivery Service | http://localhost:8001/health/live |
| Mini Shop | http://localhost:8002/health/live |
| CRM | http://localhost:8003/health/live |
| Admin UI | http://localhost:5173 |
| PostgreSQL | `localhost:5433` |
| Kafka | `localhost:9092` |

Warehouse 1C remains outside Docker Compose for Milestone 0. Kafka is available as infrastructure only; no consumer or delivery pipeline is implemented yet.
