#!/bin/sh

echo "Generating SSL certificates..."
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /certs/nginx.key -out /certs/nginx.crt \
  -config /tmp/certs/openssl.cnf
echo "Generated SSL certificates..."
