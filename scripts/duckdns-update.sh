#!/bin/bash
# DuckDNS dynamic IP update
# cron: */5 * * * * /opt/n8n/duckdns-update.sh > /dev/null 2>&1

DOMAIN="your-subdomain"        # DuckDNS subdomain (without .duckdns.org)
TOKEN="your-duckdns-token"     # DuckDNS token

curl -s "https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=" -o /opt/n8n/duckdns.log
