#!/bin/sh
set -e

# Substitute environment variables in nginx config template
envsubst '${ALLOWED_REFERRERS}' < /etc/nginx/templates/nginx.conf.template > /etc/nginx/conf.d/default.conf

# Execute the main nginx command
exec nginx -g 'daemon off;'
