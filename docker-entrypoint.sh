#!/bin/sh
set -e
mkdir -p /data
npx prisma db push
exec npx next start -H 0.0.0.0 -p "${PORT:-3000}"
