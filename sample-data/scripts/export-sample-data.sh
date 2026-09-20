#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sample_data_dir="$(cd "${script_dir}/.." && pwd)"
project_dir="$(cd "${sample_data_dir}/.." && pwd)"

duration="${1:-30m}"
output_file="${sample_data_dir}/data/oxocard-data.csv"

if [[ ! "${duration}" =~ ^[0-9]+[smhdw]$ ]]; then
    echo "Ungültiger Zeitraum: ${duration}"
    echo "Beispiele: 30m, 1h, 2d"
    exit 1
fi

mkdir -p "${project_dir}/sample-data"

remote_command="
cd /project
set -a
. ./.env
set +a

docker compose exec -T influxdb influx query \
  --host http://localhost:8086 \
  --org \"\$INFLUXDB_ORG\" \
  --token \"\$INFLUXDB_ADMIN_TOKEN\" \
  --raw '
from(bucket: \"sensor_data\")
  |> range(start: -${duration})
  |> filter(fn: (r) =>
      r._measurement == \"environment\" and
      r.device == \"oxocard01\"
  )
  |> filter(fn: (r) =>
      contains(
          value: r._field,
          set: [
              \"temperature\",
              \"humidity\",
              \"pressure\",
              \"brightness\",
              \"iaq\"
          ]
      )
  )
  |> sort(columns: [\"_time\"])
'
"

(
    cd "${project_dir}/database-vm"
    vagrant ssh -c "${remote_command}"
) > "${output_file}"

if ! grep -q '^#group' "${output_file}"; then
    echo "Fehler: Der Export enthält keine gültigen InfluxDB-Daten."
    exit 1
fi

echo "Export erfolgreich:"
echo "${output_file}"
echo "Zeilen: $(wc -l < "${output_file}")"