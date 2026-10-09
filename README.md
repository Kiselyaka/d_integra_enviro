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

Integration API applies the shared platform migration and idempotently seeds missing M6 demo configuration while starting; Mini Shop and CRM apply their own migrations. Delivery Service shares `integration_db` with Integration API and therefore does not execute the same migration concurrently. PostgreSQL initialization creates separate databases `integration_db`, `shop_db`, and `crm_db`; there are no cross-database business queries.

`CRM_BASE_URL`, `WAREHOUSE_BASE_URL`, `MINI_SHOP_BASE_URL` and retry environment values are bootstrap defaults for a fresh M6 database. Once configuration rows exist, runtime route resolution uses PostgreSQL data; it does not reread those values for every Delivery.

## Commands

```sh
make build    # build service images
make logs     # follow logs
make down     # stop containers, preserve volumes
make reset    # remove volumes and start a clean environment
make test     # run platform, Mini Shop, and CRM pytest suites
make test-e2e # run the M1 Mini Shop → Platform → CRM smoke scenario
```

Equivalent shell scripts are available in `scripts/`.

## Milestone 1 end-to-end check

After `make up` has completed and `SKU-001` is available, run:

```sh
make test-e2e
```

The script creates a unique demo order through Mini Shop, asserts its `Message` and route result in `integration_db`, asserts the Customer, Deal and position in `crm_db`, then sends the same external event again. It verifies that the duplicate returns `already_accepted` without adding another Message, route result, Customer or Deal. The test adds demo data to local Docker volumes; use `make reset` only when a clean local environment is wanted.

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
| Kafka UI (M5.5, optional) | http://localhost:8085 |

Warehouse 1C remains outside Docker Compose and is published by local Apache.
Containers reach it through `host.docker.internal:8081`; keep Apache/Laragon
and the published 1C infobase running for Warehouse E2E scenarios.

## M5.5 Kafka Runtime Visualization

Kafka UI is optional **development/diagnostic tooling**, not Platform Admin UI
and not a runtime dependency. It is isolated behind the Compose `tooling`
profile; stopping it cannot affect Platform processing.

Start it after the normal environment is running:

```sh
docker compose --profile tooling up -d kafka-ui
```

Open [http://localhost:8085](http://localhost:8085). The configured local
cluster is read-only and exposes the M5 topics, messages, partitions, consumer
groups, offsets and lag:

- `integration.delivery.requested`;
- `integration.delivery.completed`;
- `integration.delivery.dead_lettered`.

Kafka UI is not a source of truth, does not call Platform domain APIs and must
not be used for business operations. The future operational UI belongs to the
M9 Operational Query API → M10 React Admin UI path; this container can then
remain an engineering tool or be removed without changing the architecture.
