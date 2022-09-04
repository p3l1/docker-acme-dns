#!/bin/sh

# Configure database connection
echo "Database type: $DB_ENGINE"

if [ "$DB_ENGINE" == "postgres" ]; then
    DB_CONN_STR=postgres://$POSTGRES_USER:$POSTGRES_PASSWORD@database/$POSTGRES_DB?sslmode=disable
elif [ "$DB_ENGINE" == "sqlite3" ]; then
    DB_CONN_STR=/var/lib/acme-dns/database.sqlite3
else
    echo "Unkown database type! Aborting..."
    exit 1
fi

envsubst < /etc/acme-dns/template.cfg  > /etc/acme-dns/config.cfg

# Start ACME-DNS server
/usr/local/bin/acme-dns
