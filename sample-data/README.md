# Oxocard-Beispieldaten

Dieser Ordner enthält einen exportierten Datensatz der Oxocard. Damit kann das Projekt vollständig getestet werden, ohne dass eine eigene Oxocard vorhanden sein muss.

Nach dem Import stehen die Messwerte in InfluxDB zur Verfügung und werden im provisionierten Grafana-Dashboard **Oxocard Environmental Monitoring** angezeigt.

## Inhalt

```text
sample-data/
├── README.md
├── data/
│   └── oxocard-data.csv
└── scripts/
    ├── export-sample-data.sh
    └── import-sample-data.sh
```

- `data/oxocard-data.csv`: exportierte Messwerte im annotierten InfluxDB-CSV-Format
- `scripts/export-sample-data.sh`: exportiert einen Zeitraum aus der laufenden InfluxDB
- `scripts/import-sample-data.sh`: importiert die CSV-Datei in eine neue Projektumgebung

## Enthaltener Datensatz

Der mitgelieferte Datensatz enthält ungefähr 30 Minuten echte Messwerte:

| Eigenschaft | Wert |
|---|---|
| Zeitraum (UTC) | 20.09.2026, 10:03:31–10:33:29 |
| Zeitraum (Europe/Zurich) | 20.09.2026, 12:03:31–12:33:29 |
| Messpunkte | 1.782 |
| Bucket | `sensor_data` |
| Measurement | `environment` |
| Device-Tag | `oxocard01` |
| Fields | `temperature`, `humidity`, `pressure`, `brightness`, `iaq` |

## Beispieldaten importieren

### 1. Projektumgebung starten

Im Hauptordner des Projekts:

```bash
cd database-vm
vagrant up
cd ..
```

InfluxDB und Grafana werden dabei automatisch mit Docker Compose gestartet.

### 2. Importskript ausführbar machen

```bash
chmod +x sample-data/scripts/import-sample-data.sh
```

### 3. Daten importieren

```bash
./sample-data/scripts/import-sample-data.sh
```

Die Oxocard muss während des Imports nicht vorhanden oder eingeschaltet sein. Das Skript kopiert `oxocard-data.csv` in die VM und schreibt die Messpunkte in den Bucket `sensor_data`.

Ein erneuter Import derselben Datei erzeugt keine zusätzlichen Zeitpunkte. Datenpunkte mit identischem Measurement, Tag, Field und Zeitstempel werden überschrieben.

## Daten in Grafana anzeigen

Nach dem Import kann das Dashboard über folgenden Link geöffnet werden:

[Oxocard Environmental Monitoring – Beispieldaten](http://localhost:3000/d/oxocard-environment/oxocard-environmental-monitoring?orgId=1&from=1789898551000&to=1789900469000)

Der Link enthält einen absoluten Zeitraum und funktioniert daher auch dann, wenn das Projekt erst Wochen oder Monate später getestet wird.

Standardzugang der lokalen Testumgebung:

```text
Benutzer: "dein benutzer"
Passwort: "dein passwort"
```

## Herkunft der Beispieldaten

Die Datei `data/oxocard-data.csv` wurde mit dem Exportskript aus der laufenden InfluxDB exportiert. Sie enthält echte Messwerte der Oxocard und ermöglicht es, die vollständige InfluxDB- und Grafana-Umgebung auch ohne vorhandene Oxocard zu testen.

## Fehlerbehebung

### CSV-Datei wurde nicht gefunden

Prüfen, ob folgende Datei vorhanden ist:

```text
sample-data/data/oxocard-data.csv
```

### In Grafana werden keine Daten angezeigt

- Den oben angegebenen Dashboard-Link verwenden.
- Prüfen, ob das Importskript mit `Import erfolgreich.` beendet wurde.
- Kontrollieren, ob die InfluxDB- und Grafana-Container laufen.

```bash
cd database-vm
vagrant ssh -c "cd /project && docker compose ps"
```

Danach das Importskript erneut ausführen.
