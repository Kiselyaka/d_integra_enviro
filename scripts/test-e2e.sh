#!/usr/bin/env sh
set -eu

# Reproducible M1 smoke test. It uses only local Docker services and creates
# one fresh demo order plus its idempotent duplicate event.
cd "$(dirname "$0")/.."

unique_id="$(date +%s)"
customer_id="C-M1-E2E-${unique_id}"
email="m1-e2e-${unique_id}@example.test"

order_response="$(curl --fail --silent --show-error \
  --request POST http://localhost:8002/api/orders \
  --header 'Content-Type: application/json' \
  --data "{
    \"customer\": {\"customer_id\": \"${customer_id}\", \"full_name\": \"M1 E2E Customer\", \"email\": \"${email}\", \"phone\": null},
    \"shipping_address\": {\"country\": \"LV\", \"city\": \"Riga\", \"postal_code\": \"LV-1001\", \"street\": \"Example Street\", \"building\": \"1\", \"apartment\": null},
    \"items\": [{\"product_code\": \"SKU-001\", \"quantity\": 2}]
  }")"
order_id="$(printf '%s' "$order_response" | python -c 'import json,sys; print(json.load(sys.stdin)["order_id"])' | tr -d '\r\n')"
event_id="order-created-${order_id}"
correlation_id="order-${order_id}"

shop_row="$(docker compose exec -T postgres psql -U postgres -d shop_db -tAc \
  "SELECT o.status || '|' || o.total_amount || '|' || count(oi.id) FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.id WHERE o.id = '${order_id}' GROUP BY o.status, o.total_amount")"
[ "$shop_row" = "CREATED|21.00|1" ]

platform_row="$(docker compose exec -T postgres psql -U postgres -d integration_db -tAc \
  "SELECT m.status || '|' || r.status FROM messages m JOIN route_processing_results r ON r.message_id = m.id WHERE m.source_system = 'mini-shop' AND m.external_event_id = '${event_id}'")"
[ "$platform_row" = "COMPLETED|DELIVERY_REQUESTED" ]

crm_row="$(docker compose exec -T postgres psql -U postgres -d crm_db -tAc \
  "SELECT c.external_customer_id || '|' || d.external_order_id || '|' || d.amount || '|' || count(p.id) FROM customers c JOIN deals d ON d.customer_id = c.id LEFT JOIN deal_positions p ON p.deal_id = d.id WHERE d.external_order_id = '${order_id}' GROUP BY c.external_customer_id, d.external_order_id, d.amount")"
[ "$crm_row" = "${customer_id}|${order_id}|21.00|1" ]

# A duplicate is identified by the same source_system + external event_id.
duplicate_response="$(curl --fail --silent --show-error \
  --request POST http://localhost:8000/api/v1/events \
  --header 'Content-Type: application/json' \
  --data "{
    \"event_id\": \"${event_id}\",
    \"event_type\": \"order.created\",
    \"source_system\": \"mini-shop\",
    \"occurred_at\": \"2026-10-04T00:00:00Z\",
    \"correlation_id\": \"${correlation_id}\",
    \"schema_version\": 1,
    \"payload\": {
      \"order_id\": \"${order_id}\",
      \"customer\": {\"customer_id\": \"${customer_id}\", \"full_name\": \"M1 E2E Customer\", \"email\": \"${email}\", \"phone\": null},
      \"shipping_address\": {\"country\": \"LV\", \"city\": \"Riga\", \"postal_code\": \"LV-1001\", \"street\": \"Example Street\", \"building\": \"1\", \"apartment\": null},
      \"items\": [{\"product_code\": \"SKU-001\", \"name\": \"Example Product\", \"quantity\": 2, \"unit_price\": \"10.50\"}],
      \"currency\": \"EUR\",
      \"total_amount\": \"21.00\"
    }
  }")"
duplicate_status="$(printf '%s' "$duplicate_response" | python -c 'import json,sys; print(json.load(sys.stdin)["status"])' | tr -d '\r\n')"
[ "$duplicate_status" = "already_accepted" ]

platform_counts="$(docker compose exec -T postgres psql -U postgres -d integration_db -tAc \
  "SELECT (SELECT count(*) FROM messages WHERE source_system = 'mini-shop' AND external_event_id = '${event_id}') || '|' || (SELECT count(*) FROM route_processing_results r JOIN messages m ON m.id = r.message_id WHERE m.source_system = 'mini-shop' AND m.external_event_id = '${event_id}')")"
[ "$platform_counts" = "1|1" ]

crm_counts="$(docker compose exec -T postgres psql -U postgres -d crm_db -tAc \
  "SELECT (SELECT count(*) FROM customers WHERE external_customer_id = '${customer_id}') || '|' || (SELECT count(*) FROM deals WHERE external_order_id = '${order_id}')")"
[ "$crm_counts" = "1|1" ]

printf 'M1 E2E passed: order_id=%s, event_id=%s\n' "$order_id" "$event_id"
