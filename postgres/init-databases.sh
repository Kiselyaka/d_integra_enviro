#!/bin/sh
set -eu

psql --set=ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  --set=integration_db_password="$INTEGRATION_DB_PASSWORD" \
  --set=shop_db_password="$SHOP_DB_PASSWORD" \
  --set=crm_db_password="$CRM_DB_PASSWORD" <<'SQL'
CREATE USER integration_user WITH PASSWORD :'integration_db_password';
CREATE DATABASE integration_db OWNER integration_user;

CREATE USER shop_user WITH PASSWORD :'shop_db_password';
CREATE DATABASE shop_db OWNER shop_user;

CREATE USER crm_user WITH PASSWORD :'crm_db_password';
CREATE DATABASE crm_db OWNER crm_user;
SQL
