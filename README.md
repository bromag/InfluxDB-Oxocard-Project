# Entwicklung einer Zeitreihendatenbank für IoT-Sensordaten mit InfluxDB

## Projektbeschreibung

Dieses Projekt wird im Rahmen des Moduls **Datenbankdesign** erstellt.

Ziel des Projekts ist die Konzeption, Implementierung und Evaluation einer Zeitreihendatenbank mit **InfluxDB** zur Speicherung und Analyse von Sensordaten einer **Oxocard Science+**.

Der Schwerpunkt liegt auf dem **Datenbankdesign**. Dabei werden verschiedene Modellierungsansätze untersucht und hinsichtlich Speicherbedarf, Performance und Erweiterbarkeit bewertet.

Die Oxocard dient ausschliesslich als Datenquelle für realitätsnahe Sensordaten.

---

# Projektziel

Es soll untersucht werden, wie eine Zeitreihendatenbank für IoT-Sensordaten aufgebaut werden kann, um Messwerte effizient zu speichern und performant auszuwerten.

Dabei werden insbesondere folgende Punkte betrachtet:

- Analyse der Anforderungen
- Entwurf eines geeigneten Datenmodells
- Modellierung von Buckets, Measurements, Tags und Fields
- Implementierung mit InfluxDB
- Evaluation des Datenbankdesigns
- Performance- und Speicherbetrachtung
- Visualisierung der Daten mit Grafana

---

# Forschungsfrage

> **Wie kann eine Zeitreihendatenbank mit InfluxDB für IoT-Sensordaten so entworfen werden, dass Sensordaten effizient gespeichert, einfach erweitert und performant ausgewertet werden können?**

---

# Systemarchitektur

```text
               Oxocard Science+
                      │
                 HTTP POST
                      │
                      ▼
               InfluxDB 2.x
                      │
          ┌───────────┴───────────┐
          │                       │
          ▼                       ▼
     Flux Queries             Grafana
          │
          ▼
      Dashboard
```

---

# Datenbankdesign

## Bucket

Es wird ein gemeinsamer Bucket verwendet.

| Bucket | Beschreibung |
|---------|--------------|
| `sensor_data` | Enthält sämtliche Sensordaten der Oxocard |

### Begründung

Da alle Sensordaten derselben Anwendung zugeordnet sind und dieselbe Retention Policy besitzen, genügt ein einzelner Bucket. Dadurch bleibt die Datenstruktur übersichtlich und einfach erweiterbar.

---

## Measurements

Die Sensordaten werden nach ihrem fachlichen Zusammenhang gruppiert.

| Measurement | Beschreibung |
|-------------|--------------|
| `environment` | Umweltdaten |
| `motion` | Bewegungsdaten |

### environment

Enthält beispielsweise:

- Temperatur
- Luftfeuchtigkeit
- Luftdruck
- Helligkeit

### motion

Enthält beispielsweise:

- Beschleunigung X
- Beschleunigung Y
- Beschleunigung Z

### Begründung

Die Trennung erfolgt nach der Art der Messdaten. Dadurch können Umweltdaten und Bewegungsdaten unabhängig voneinander gespeichert und ausgewertet werden.

---

## Tags

Tags enthalten beschreibende Informationen, nach denen häufig gefiltert wird.

| Tag | Beschreibung |
|-----|--------------|
| `device` | Sensorgerät |
| `room` | Raum |
| `location` | Standort |

### Beispiel

```
device = oxocard01
room = labor
location = TEKO
```

### Begründung

Tags werden von InfluxDB indexiert und ermöglichen schnelle Filter- und Gruppierungsabfragen.

---

## Fields

Fields enthalten die eigentlichen Messwerte.

### Measurement `environment`

| Field | Einheit |
|--------|----------|
| temperature | °C |
| humidity | % |
| pressure | hPa |
| brightness | Lux |

### Measurement `motion`

| Field | Einheit |
|--------|----------|
| accel_x | m/s² |
| accel_y | m/s² |
| accel_z | m/s² |

### Begründung

Messwerte besitzen sehr viele unterschiedliche Werte und eignen sich deshalb als Fields. Eine Speicherung als Tags würde zu einer unnötig hohen Kardinalität führen und die Performance negativ beeinflussen.

---

## Beispiel eines Datenpunktes

```text
environment,device=oxocard01,room=labor,location=TEKO temperature=23.4,humidity=48,pressure=1012,brightness=310
```

---

# Technologien

| Technologie | Verwendungszweck |
|--------------|------------------|
| Vagrant | Reproduzierbare Entwicklungsumgebung |
| Ubuntu Server | Virtuelle Maschine |
| Docker Compose | Container-Orchestrierung |
| InfluxDB 2.x | Zeitreihendatenbank |
| Flux | Datenanalyse |
| Grafana | Visualisierung |
| Oxocard Science+ | Sensordatenerfassung |
| Git | Versionsverwaltung |

---

# Projektstatus

## Infrastruktur

- [x] Projektidee definiert
- [x] Vagrant-Umgebung erstellt
- [x] Docker Compose eingerichtet
- [x] InfluxDB installiert
- [x] Grafana installiert
- [x] Grafana automatisch mit InfluxDB verbunden

## Datenbankdesign

- [x] Forschungsfrage definiert
- [x] Bucket-Design erstellt
- [x] Measurement-Konzept erstellt
- [x] Tags und Fields definiert
- [ ] Retention Policy definieren
- [ ] Flux-Abfragen entwickeln
- [ ] Performance evaluieren

## Datenerfassung

- [x] Oxocard mit WLAN verbunden
- [x] HTTP-Kommunikation getestet
- [x] Erste Sensordaten erfolgreich in InfluxDB gespeichert
- [ ] Weitere Sensoren integrieren
- [ ] Dashboard erstellen

---

# Projektstruktur

```text
.
├── README.md
├── Vagrantfile
├── docker-compose.yml
├── .env.example
├── scripts/
│   ├── 01-system.sh
│   ├── 02-docker.sh
│   ├── 03-tools.sh
│   └── 04-start-stack.sh
├── grafana/
│   └── provisioning/
├── oxocard/
├── diagrams/
└── docs/
```

---

# Aktueller Projektstand

Die Entwicklungsumgebung wurde vollständig automatisiert.

Nach einem

```bash
vagrant up
```

werden automatisch

- die virtuelle Maschine erstellt,
- Docker installiert,
- InfluxDB initialisiert,
- Grafana gestartet,
- die Data Source konfiguriert.

Die Oxocard Science+ sendet bereits erfolgreich Sensordaten über HTTP an InfluxDB.

---

# Nächste Schritte

1. Weitere Sensoren der Oxocard integrieren.
2. Retention Policy definieren.
3. Flux-Abfragen entwickeln.
4. Dashboard in Grafana erstellen.
5. Datenbankdesign evaluieren und dokumentieren.