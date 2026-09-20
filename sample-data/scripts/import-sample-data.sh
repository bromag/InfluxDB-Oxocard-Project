#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sample_data_dir="$(cd "${script_dir}/.." && pwd)"
project_dir="$(cd "${sample_data_dir}/.." && pwd)"

data_file="${sample_data_dir}/data/oxocard-data.csv"
guest_file="/tmp/oxocard-data.csv"

if [[ ! -f "${data_file}" ]]; then
    echo "Fehler: ${data_file} wurde nicht gefunden."
    exit 1
fi

cd "${project_dir}/database-vm"

echo "Übertrage Beispieldaten in die VM ..."
vagrant upload "${data_file}" "${guest_file}"

echo "Importiere Beispieldaten in InfluxDB ..."

vagrant ssh -c '
cd /project

set -a
. ./.env
set +a

docker compose cp /tmp/oxocard-data.csv influxdb:/tmp/oxocard-data.csv

docker compose exec -T influxdb influx write \
  --host http://localhost:8086 \
  --org "$INFLUXDB_ORG" \
  --bucket "$INFLUXDB_BUCKET" \
  --token "$INFLUXDB_ADMIN_TOKEN" \
  --format csv \
  --file /tmp/oxocard-data.csv </dev/null
'

echo "Import erfolgreich."
echo "Die Oxocard-Messwerte sind jetzt im Bucket sensor_data vorhanden."