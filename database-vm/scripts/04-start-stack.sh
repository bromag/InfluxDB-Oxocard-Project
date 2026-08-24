#!/usr/bin/env bash

set -euo pipefail

project_dir=/project
compose_file="${project_dir}/docker-compose.yml"

if [ ! -f "${compose_file}" ]; then
    echo "ERROR: ${compose_file} is missing. Check the Vagrant synced-folder mount." >&2
    exit 1
fi

cd "${project_dir}"

echo "==> Starting the honeypot stack..."
docker compose up -d --build --remove-orphans
docker compose ps
