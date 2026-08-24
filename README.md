# Echtzeit-Sensordaten mit Oxocard, InfluxDB und Grafana

> Projektdokumentation im Modul **Datenbankdesign**
> Aufbau einer reproduzierbaren IoT-Zeitreihenplattform mit Oxocard Science+, InfluxDB, Grafana, Docker Compose und Vagrant

## Inhaltsverzeichnis

1. [Einleitung](#1-einleitung)
2. [Ausgangslage und Problemstellung](#2-ausgangslage-und-problemstellung)
3. [Ziele und Abgrenzung](#3-ziele-und-abgrenzung)
4. [Forschungsfrage](#4-forschungsfrage)
5. [Systemarchitektur](#5-systemarchitektur)
6. [Technologieentscheidungen](#6-technologieentscheidungen)
7. [Datenfluss](#7-datenfluss)
8. [Datenmodell in InfluxDB](#8-datenmodell-in-influxdb)
9. [Oxocard-Programm](#9-oxocard-programm)
10. [Docker-Compose-Umgebung](#10-docker-compose-umgebung)
11. [Vagrant und Provisionierung](#11-vagrant-und-provisionierung)
12. [Grafana-Provisionierung](#12-grafana-provisionierung)
13. [Aufbau des Grafana-Dashboards](#13-aufbau-des-grafana-dashboards)
14. [Installation und Inbetriebnahme](#14-installation-und-inbetriebnahme)
15. [Betrieb und Kontrolle](#15-betrieb-und-kontrolle)
16. [Screenshots und Nachweise](#16-screenshots-und-nachweise)
17. [Herausforderungen und Erkenntnisse](#17-herausforderungen-und-erkenntnisse)
18. [Projektstatus](#18-projektstatus)
19. [Ausblick](#19-ausblick)
20. [Fazit](#20-fazit)

---

## 1. Einleitung

In IoT-Anwendungen entstehen fortlaufend Messwerte, die immer einem Zeitpunkt zugeordnet sind. Dazu gehören beispielsweise Temperatur, Luftfeuchtigkeit, Luftdruck und Helligkeit. Solche Daten unterscheiden sich von klassischen Geschäftsdaten: Sie werden regelmässig geschrieben, wachsen rasch an und werden hauptsächlich über Zeiträume, Trends und Aggregationen ausgewertet.

Dieses Projekt zeigt den vollständigen Weg solcher Sensordaten. Eine **Oxocard Science+** erfasst Umgebungswerte und überträgt sie alle fünf Sekunden per HTTP an **InfluxDB**. InfluxDB speichert die Messwerte als Zeitreihen. **Grafana** greift auf diese Daten zu und stellt aktuelle Werte sowie zeitliche Verläufe in einem Dashboard dar.

Die Serverkomponenten laufen in Docker-Containern innerhalb einer mit **Vagrant** bereitgestellten Ubuntu-VM. Dadurch kann die Umgebung reproduzierbar aufgebaut, getestet und bei Bedarf vollständig neu erstellt werden. Der fachliche Schwerpunkt des Projekts liegt auf dem Datenbankdesign und auf der Frage, wie Sensordaten effizient, verständlich und erweiterbar modelliert werden können.

## 2. Ausgangslage und Problemstellung

Eine herkömmliche relationale Datenbank könnte Sensordaten grundsätzlich ebenfalls speichern. Für dieses Anwendungsszenario wären jedoch zusätzliche Überlegungen zu Zeitindizes, Partitionierung, Aufbewahrungsdauer und regelmässigen Aggregationen nötig. Eine Zeitreihendatenbank bringt diese Konzepte bereits als Kernfunktionen mit.

Die konkrete Aufgabenstellung besteht darin, eine kleine, aber vollständige IoT-Datenpipeline aufzubauen:

- Messwerte werden auf einem physischen Gerät erfasst.
- Die Übertragung erfolgt automatisiert über das lokale Netzwerk.
- Die Daten werden mit Zeitstempel und Gerätebezug gespeichert.
- Aktuelle Zustände und historische Entwicklungen werden visualisiert.
- Die gesamte Serverumgebung soll wiederholbar installiert werden können.

Dabei müssen nicht nur einzelne Komponenten funktionieren. Entscheidend ist ihr Zusammenspiel: Netzwerkzugriff, Authentifizierung, Datenmodell, Container-Startreihenfolge und Grafana-Abfragen müssen aufeinander abgestimmt sein.

## 3. Ziele und Abgrenzung

### 3.1 Projektziele

Das Projekt verfolgt folgende Ziele:

- Aufbau einer funktionierenden End-to-End-Pipeline von der Oxocard bis zum Dashboard
- Erfassung von Temperatur, Luftfeuchtigkeit, Luftdruck und Helligkeit
- Übertragung der Messwerte in einem Intervall von fünf Sekunden
- Speicherung der Daten in einer für Zeitreihen optimierten Datenbank
- sinnvolle Modellierung von Bucket, Measurement, Tags und Fields
- Visualisierung aktueller Werte und zeitlicher Verläufe
- automatisierte Bereitstellung der Infrastruktur mit Vagrant und Docker Compose
- persistente Speicherung der Daten über Container-Neustarts hinweg
- nachvollziehbare Dokumentation der Architektur und der Technologieentscheide
- Schaffung einer Grundlage für spätere Erweiterungen und Auswertungen

### 3.2 Abgrenzung

Im aktuellen Projektumfang nicht vollständig umgesetzt sind:

- produktive Hochverfügbarkeit oder Clustering
- verschlüsselte Kommunikation über HTTPS/TLS
- zentral verwaltete Geheimnisse
- automatische Alarmierung bei Grenzwertüberschreitungen
- mehrere geografisch verteilte Sensorgeräte
- eine abschliessende Last- und Langzeitmessung
- automatische Provisionierung des Dashboard-JSON im Repository

Diese Punkte sind mögliche Weiterentwicklungen, gehören aber nicht zum Kernnachweis dieses Prototyps.

## 4. Forschungsfrage

> **Wie kann eine Zeitreihendatenbank mit InfluxDB für IoT-Sensordaten so entworfen werden, dass Sensordaten effizient gespeichert, einfach erweitert und performant ausgewertet werden können?**

Die Forschungsfrage wird im Projekt praktisch untersucht. Im Vordergrund stehen das Datenmodell, die Schreibstruktur, die Abfragen in Flux sowie die Auswirkungen von Tags und Fields auf Filterbarkeit und Kardinalität.

## 5. Systemarchitektur

```text
┌──────────────────────────┐
│ Oxocard Science+         │
│                          │
│ Temperatur               │
│ Luftfeuchtigkeit         │
│ Luftdruck                │
│ Helligkeit               │
└────────────┬─────────────┘
             │ HTTP POST / InfluxDB Line Protocol
             │ Intervall: 5 Sekunden
             ▼
┌────────────────────────────────────────────────────┐
│ Ubuntu-VM, bereitgestellt mit Vagrant              │
│                                                    │
│  ┌──────────────────┐    ┌─────────────────────┐  │
│  │ InfluxDB 2.7     │◄───│ Grafana 13.1       │  │
│  │ Port 8086        │    │ Port 3000           │  │
│  │ Bucket:          │    │ Flux-Datenquelle    │  │
│  │ sensor_data      │    │ Dashboard           │  │
│  └────────┬─────────┘    └─────────────────────┘  │
│           │                                        │
│  persistente Docker-Volumes                        │
└────────────────────────────────────────────────────┘
             ▲
             │ Portweiterleitung / privates Netzwerk
             │
┌────────────┴─────────────┐
│ Hostsystem              │
│ Browser und Verwaltung  │
└──────────────────────────┘
```

Die Architektur trennt die Datenerfassung, Speicherung und Visualisierung bewusst voneinander. Jede Komponente übernimmt eine klar definierte Aufgabe und kann später unabhängig ausgetauscht oder erweitert werden.

## 6. Technologieentscheidungen

### 6.1 Oxocard Science+

Die Oxocard Science+ dient als IoT-Datenquelle. Sie eignet sich für den Prototyp, weil mehrere benötigte Sensoren bereits integriert sind und keine zusätzliche Verkabelung erforderlich ist. Das Gerät kann über WLAN kommunizieren, HTTP-Anfragen senden und die erfassten Werte gleichzeitig auf dem eigenen Display darstellen.

**Gründe für die Wahl:**

- integrierte Sensorik für mehrere Umgebungsgrössen
- direkter Praxisbezug statt ausschliesslich simulierter Testdaten
- WLAN- und HTTP-Fähigkeit
- einfache Programmierung und unmittelbare Anzeige auf dem Gerät
- kompakte Hardware für Demonstrationen

### 6.2 InfluxDB 2.7

InfluxDB ist eine speziell für Zeitreihendaten entwickelte Datenbank. Jeder Datenpunkt wird mit einem Zeitstempel gespeichert. Daten lassen sich nach Zeitbereich, Gerät und Messgrösse filtern sowie über Zeitfenster aggregieren.

**Gründe für die Wahl:**

- optimiert für kontinuierliche Schreibvorgänge
- passendes Datenmodell aus Measurements, Tags und Fields
- integrierte HTTP-Write-API
- kompaktes Line Protocol für Sensordaten
- Abfragesprache Flux für Filter und Aggregationen
- direkte Integration in Grafana
- Aufbewahrungsregeln können auf Bucket-Ebene definiert werden

### 6.3 Grafana 13.1

Grafana übernimmt die Darstellung der gespeicherten Daten. Die Daten bleiben in InfluxDB; Grafana fragt sie bei Bedarf ab und visualisiert sie in Panels.

**Gründe für die Wahl:**

- gute Unterstützung für InfluxDB und Flux
- geeignete Paneltypen für Monitoring und Zeitreihen
- automatische Aktualisierung von Dashboards
- zentrale Darstellung mehrerer Messgrössen
- Dashboards können als JSON exportiert und versioniert werden
- weit verbreitetes Werkzeug in Monitoring- und Observability-Umgebungen

### 6.4 Docker

InfluxDB und Grafana laufen als getrennte Container. Die Container enthalten die benötigte Laufzeitumgebung und reduzieren Abhängigkeiten vom Betriebssystem der VM.

**Vorteile im Projekt:**

- definierte und reproduzierbare Softwareversionen
- klare Trennung der Dienste
- einfache Neustarts und Aktualisierungen
- persistente Datenhaltung über benannte Volumes
- kein manuelles Installieren von InfluxDB und Grafana auf dem Host

### 6.5 Docker Compose

Docker Compose beschreibt beide Dienste, ihre Ports, Volumes, Umgebungsvariablen, Abhängigkeiten und das gemeinsame Netzwerk in einer Datei. Damit kann der gesamte Stack mit einem Befehl gestartet oder gestoppt werden.

**Gründe für die Wahl:**

- zentrale, lesbare Infrastrukturdefinition
- definierte Startabhängigkeit zwischen InfluxDB und Grafana
- automatische Erstellung des internen Netzwerks
- einfache Übergabe von Konfigurationswerten aus `.env`
- geeignet für einen überschaubaren Stack auf einem einzelnen Server

Docker Compose ist in diesem Projekt bewusst keine Cluster-Orchestrierung. Für den Prototyp wäre Kubernetes unverhältnismässig komplex.

### 6.6 Vagrant

Vagrant erstellt eine Ubuntu-24.04-VM und führt die Provisionierungsskripte aus. Unterstützt werden VirtualBox und Parallels. Die VM erhält zwei virtuelle CPUs und 4096 MB Arbeitsspeicher.

**Gründe für die Wahl:**

- reproduzierbare Betriebssystemumgebung
- Trennung vom persönlichen Hostsystem
- automatisierte Installation von Docker und Hilfswerkzeugen
- einheitlicher Ablauf auf verschiedenen Entwicklungsrechnern
- VM kann kontrolliert beendet, neu gestartet oder vollständig neu aufgebaut werden

### 6.7 Zusammenspiel der Technologien

| Ebene | Technologie | Aufgabe |
|---|---|---|
| Datenerfassung | Oxocard Science+ | Sensorwerte messen und übertragen |
| Schnittstelle | HTTP + Line Protocol | kompakte Datenübertragung |
| Datenhaltung | InfluxDB | Zeitreihen persistent speichern und abfragen |
| Visualisierung | Grafana | aktuelle Werte, Trends und Rohdaten anzeigen |
| Containerisierung | Docker | Dienste isoliert ausführen |
| Stack-Definition | Docker Compose | Container gemeinsam konfigurieren und starten |
| Virtualisierung | Vagrant + Ubuntu | reproduzierbaren Server bereitstellen |

## 7. Datenfluss

Der vollständige Datenfluss läuft in sieben Schritten ab:

1. Die Oxocard liest Temperatur, Luftfeuchtigkeit, Luftdruck und Umgebungshelligkeit aus.
2. Aus den vier Werten wird eine Zeile im InfluxDB Line Protocol erstellt.
3. Die Oxocard ergänzt den HTTP-Header `Authorization: Token ...` und setzt den Inhaltstyp auf `text/plain`.
4. Das Gerät sendet die Zeile per HTTP POST an `/api/v2/write`.
5. InfluxDB authentifiziert die Anfrage und speichert den Datenpunkt im Bucket `sensor_data`.
6. Grafana führt Flux-Abfragen gegen die provisionierte InfluxDB-Datenquelle aus.
7. Das Dashboard aktualisiert die Stat-, Time-Series- und Tabellen-Panels.

Beispiel einer übertragenen Zeile:

```text
environment,device=oxocard01 temperature=23.4,humidity=48.0,pressure=1012.0,brightness=310.0
```

Die Oxocard übermittelt in der aktuellen Version keinen eigenen Zeitstempel. InfluxDB vergibt deshalb beim Eingang serverseitig den Zeitstempel. Der Query-Parameter `precision=s` definiert Sekunden als Genauigkeit für den Fall, dass später ein Zeitstempel mitgesendet wird.

Bei einem Intervall von fünf Sekunden entstehen pro Gerät:

- 12 Schreibvorgänge pro Minute
- 720 Schreibvorgänge pro Stunde
- 17'280 Datenpunkte pro Tag
- 69'120 einzelne Field-Werte pro Tag, da jeder Datenpunkt vier Messwerte enthält

Diese Menge ist für den Prototyp klein, zeigt aber bereits das typische lineare Wachstum einer Zeitreihenanwendung.

## 8. Datenmodell in InfluxDB

### 8.1 Organisation und Bucket

| Element | Aktueller Wert | Bedeutung |
|---|---|---|
| Organisation | `TEKO` | logische Zuordnung von Benutzern, Buckets und Berechtigungen |
| Bucket | `sensor_data` | Speicherort sämtlicher Sensordaten |

Ein gemeinsamer Bucket ist sinnvoll, weil die Daten zur gleichen Anwendung gehören und aktuell dieselben Anforderungen an Speicherung und Aufbewahrung besitzen. Eine konkrete Retention-Dauer ist in der vorliegenden Compose-Konfiguration noch nicht explizit definiert und muss im Rahmen der Langzeitstrategie festgelegt werden.

### 8.2 Measurement

Das aktuell verwendete Measurement lautet:

```text
environment
```

Es gruppiert Messgrössen mit demselben fachlichen Kontext und ähnlichem Erfassungsintervall. Ein zusätzliches Measurement wie `motion` ist für eine spätere Integration von Beschleunigungswerten vorgesehen, wird vom aktuellen Sendeprogramm jedoch noch nicht geschrieben.

### 8.3 Tags

Aktuell wird folgender Tag übertragen:

| Tag | Beispiel | Zweck |
|---|---|---|
| `device` | `oxocard01` | eindeutige Zuordnung der Messwerte zu einem Gerät |

Mögliche spätere Tags sind `room` oder `location`. Tags eignen sich für Werte, nach denen häufig gefiltert oder gruppiert wird. InfluxDB indexiert Tags. Deshalb dürfen stark wechselnde Werte wie Temperatur oder eine zufällige ID nicht als Tags modelliert werden, da dies zu hoher Kardinalität führen würde.

### 8.4 Fields

| Field | Einheit | Bedeutung |
|---|---:|---|
| `temperature` | °C | gemessene Umgebungstemperatur |
| `humidity` | % | relative Luftfeuchtigkeit |
| `pressure` | hPa | Luftdruck |
| `brightness` | lx | Umgebungshelligkeit |

Fields enthalten die eigentlichen Messwerte. Sie sind nicht für jeden einzelnen Wert indexiert und eignen sich deshalb für kontinuierlich wechselnde numerische Daten.

### 8.5 Zeitstempel

Jeder gespeicherte Datenpunkt erhält einen Zeitstempel. Da die Oxocard aktuell keinen Zeitstempel mitsendet, verwendet InfluxDB den Zeitpunkt des Empfangs. Das vereinfacht den Prototyp, macht die Zeit aber abhängig von Netzwerkverzögerung und Serveruhr. Für eine spätere Offline-Pufferung sollte die Oxocard selbst synchronisierte Zeitstempel mitsenden.

### 8.6 Bewertung des Modells

Das gewählte Schema ist kompakt und erweiterbar:

- Vier gleichzeitig erfasste Umgebungswerte werden in einem gemeinsamen Datenpunkt geschrieben.
- Der Gerätebezug ist als indexierter Tag schnell filterbar.
- Neue Geräte können denselben Aufbau mit einem anderen `device`-Wert verwenden.
- Weitere Umgebungswerte können als Fields ergänzt werden.
- Fachlich andersartige und anders getaktete Daten können in einem separaten Measurement gespeichert werden.

Wichtig ist, die Tag-Kardinalität kontrolliert zu halten. Eine Kombination aus wenigen Geräten, Räumen und Standorten bleibt effizient. Unbegrenzte oder einmalige Werte gehören nicht in Tags.

## 9. Oxocard-Programm

Die Oxocard-Programme befinden sich im Verzeichnis `oxocard/`. Die Dateien zeigen mehrere Entwicklungsstufen:

| Datei | Zweck |
|---|---|
| `Test connection.npy` | prüft die Erreichbarkeit des InfluxDB-Health-Endpunkts |
| `influxdbdata.npy` | liest und sendet einmalig einen Datenpunkt |
| `autodata.npy` | sendet die Messwerte periodisch alle fünf Sekunden |
| `autoinfluxdata.npy` | kombiniert periodischen Upload und Anzeige auf dem Oxocard-Display |

Obwohl die Dateiendung `.npy` üblicherweise für NumPy-Dateien verwendet wird, enthalten diese Dateien lesbaren Oxocard-Programmcode.

### 9.1 Konfiguration des Endpunkts

Der Write-Endpunkt enthält Organisation, Bucket und Zeitpräzision:

```text
http://<ERREICHBARE-IP>:8086/api/v2/write?org=TEKO&bucket=sensor_data&precision=s
```

Die im Programm eingetragene IP-Adresse muss aus dem WLAN der Oxocard erreichbar sein. `localhost` wäre falsch, weil es aus Sicht der Oxocard auf die Oxocard selbst zeigen würde. Je nach Netzwerk wird die LAN-Adresse des Hostsystems oder eine direkt erreichbare VM-Adresse verwendet.

### 9.2 Authentifizierung und Header

Der API-Token wird im Authorization-Header übertragen:

```text
Authorization: Token <INFLUXDB_TOKEN>
Content-Type: text/plain
```

Der Token benötigt Schreibberechtigung für den Bucket `sensor_data`. Für eine Schulungsumgebung ist ein statischer Token einfach handhabbar. Für den produktiven Betrieb sollte er nicht im Quellcode gespeichert, regelmässig gewechselt und auf die minimal nötigen Rechte beschränkt werden.

### 9.3 Auslesen der Sensoren

Das Programm verwendet folgende Funktionen:

```text
getTemperature()   → Temperatur
getHumidity()      → relative Luftfeuchtigkeit
getPressure()      → Luftdruck
getAmbientLux()    → Umgebungshelligkeit
```

Die Werte werden in die Variablen `temperature`, `humidity`, `pressure` und `lux` übernommen. Im Line Protocol heisst das Helligkeitsfeld bewusst `brightness`.

### 9.4 Zeitsteuerung

In `autoinfluxdata.npy` wird über `millis()` geprüft, ob seit dem letzten Versand mindestens 5000 Millisekunden vergangen sind. Damit werden neue Daten ungefähr alle fünf Sekunden übertragen, während die Anzeige weiterhin aktualisiert werden kann.

### 9.5 Aufbau des Line Protocol

Der Request-Body wird schrittweise zusammengesetzt:

```text
environment,device=oxocard01 temperature=<WERT>,humidity=<WERT>,pressure=<WERT>,brightness=<WERT>
```

Dabei gelten folgende Rollen:

- `environment` ist das Measurement.
- `device=oxocard01` ist ein Tag.
- Nach dem Leerzeichen folgen vier Fields.
- Kommas trennen Tags beziehungsweise Fields.

Ein syntaktischer Fehler, ein fehlendes Leerzeichen oder ein nichtnumerischer Field-Wert führt dazu, dass InfluxDB den Datenpunkt ablehnt.

### 9.6 Upload und Statusanzeige

`postRequest(url, body)` führt die HTTP-Anfrage aus. Bei Erfolg erscheint `Upload successful`; bei einem Fehler wird `Upload failed` ausgegeben. Die Variante `autoinfluxdata.npy` zeigt zusätzlich die vier Messwerte und den Verbindungsstatus auf dem Oxocard-Display an.

Die Rückmeldung erleichtert die Inbetriebnahme, ersetzt aber noch kein dauerhaftes Fehlerprotokoll. Nicht erfolgreich gesendete Werte werden aktuell nicht gepuffert oder erneut übertragen.

## 10. Docker-Compose-Umgebung

Die Datei `docker-compose.yml` beschreibt zwei Services.

### 10.1 InfluxDB-Service

Der Service verwendet das Image `influxdb:2.7` und veröffentlicht Port `8086`. Beim ersten Start richtet InfluxDB anhand der `.env`-Werte Benutzer, Organisation, Bucket und Admin-Token ein.

Verwendete Initialisierungsvariablen:

```text
DOCKER_INFLUXDB_INIT_MODE
DOCKER_INFLUXDB_INIT_USERNAME
DOCKER_INFLUXDB_INIT_PASSWORD
DOCKER_INFLUXDB_INIT_ORG
DOCKER_INFLUXDB_INIT_BUCKET
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN
```

Die Volumes `influxdb-data` und `influxdb-config` speichern Daten und Konfiguration ausserhalb des Container-Dateisystems. Ein Container kann dadurch ersetzt werden, ohne dass die Zeitreihen verloren gehen.

Der Healthcheck ruft regelmässig `http://localhost:8086/health` im Container auf. Erst wenn InfluxDB als gesund gilt, darf Grafana starten. Das verhindert insbesondere beim ersten Setup einen typischen Fehler durch eine noch nicht betriebsbereite Datenbank.

### 10.2 Grafana-Service

Grafana verwendet das Image `grafana/grafana:13.1.0` und veröffentlicht Port `3000`. Die Registrierung weiterer Benutzer ist deaktiviert. Der Dienst bindet das Verzeichnis `grafana/provisioning` schreibgeschützt ein.

Das Volume `grafana-data` persistiert unter anderem die interne Grafana-Datenbank und manuell erstellte Dashboards. `depends_on` mit `condition: service_healthy` sorgt dafür, dass Grafana erst nach einem erfolgreichen InfluxDB-Healthcheck startet.

Die aktuelle Compose-Datei setzt den Grafana-Administrator direkt auf `admin`/`admin`. Dies ist für eine isolierte Demonstrationsumgebung verständlich, muss aber für jede gemeinsam genutzte oder produktive Installation geändert werden. Die Variablen `GF_ADMIN_USER` und `GF_ADMIN_PASSWORD` aus `.env.example` werden von der aktuellen Compose-Datei noch nicht verwendet.

### 10.3 Netzwerk

Docker Compose erstellt das benannte Netzwerk `influxdb-network`. Innerhalb dieses Netzwerks kann Grafana InfluxDB über den Servicenamen erreichen:

```text
http://influxdb:8086
```

Diese interne Adresse ist stabil und unabhängig von der IP-Adresse des Containers. Die Oxocard befindet sich ausserhalb des Docker-Netzwerks und verwendet deshalb eine vom WLAN erreichbare IP-Adresse.

### 10.4 Neustartverhalten

Beide Services verwenden `restart: unless-stopped`. Nach einem normalen Neustart der VM startet Docker die Container deshalb automatisch wieder, sofern sie zuvor nicht ausdrücklich gestoppt wurden.

## 11. Vagrant und Provisionierung

Das Vagrant-Projekt liegt im Unterordner `database-vm/`. Das `Vagrantfile` verwendet `bento/ubuntu-24.04`, setzt den Hostnamen `database-server` und konfiguriert:

- 2 virtuelle CPUs
- 4096 MB RAM
- private VM-Adresse `192.168.56.10`
- Weiterleitung von Port 3000 für Grafana
- Weiterleitung von Port 8086 für InfluxDB
- synchronisiertes Projektverzeichnis unter `/project`

Für VirtualBox wird ein bidirektionaler Shared Folder verwendet. Bei Parallels wird das Projekt per `rsync` in die VM übertragen. Änderungen auf dem Host müssen bei dieser Variante gegebenenfalls mit `vagrant rsync` synchronisiert werden.

Die Provisionierung ist in vier Skripte aufgeteilt:

| Skript | Aufgabe |
|---|---|
| `01-system.sh` | aktualisiert Paketlisten und installiert Systemabhängigkeiten |
| `02-docker.sh` | installiert Docker Engine und das Compose-Plugin |
| `03-tools.sh` | installiert Werkzeuge wie Git, jq, tree, vim und htop |
| `04-start-stack.sh` | startet den Compose-Stack im Verzeichnis `/project` |

Der Stack wird standardmässig beim ersten `vagrant up` gestartet. Mit `DATABASE_AUTOSTART=0` kann dieser Schritt beim Provisionieren unterdrückt werden.

Nach `vagrant halt` und einem erneuten `vagrant up` laufen die Provisioner normalerweise nicht nochmals. Aufgrund von `restart: unless-stopped` sollten die Container nach dem Start des Docker-Dienstes dennoch automatisch wieder anlaufen. Falls ein Provisionierungsschritt erneut ausgeführt werden soll, wird `vagrant provision` oder `vagrant up --provision` verwendet.

## 12. Grafana-Provisionierung

### 12.1 Datenquelle

Die Datei `grafana/provisioning/datasources/influxdb.yml` richtet die InfluxDB-Datenquelle beim Start von Grafana automatisch ein.

Wichtige Einstellungen:

| Einstellung | Wert | Zweck |
|---|---|---|
| Name | `InfluxDB` | Anzeigename in Grafana |
| UID | `influxdb` | stabile Referenz für Dashboards |
| URL | `http://influxdb:8086` | interne Docker-Adresse |
| Query-Sprache | `Flux` | verwendete Abfragesprache |
| Organisation | `TEKO` | InfluxDB-Organisation |
| Standard-Bucket | `sensor_data` | Quelle für Sensorwerte |
| Standardquelle | `true` | automatische Auswahl in neuen Panels |

Der Token in der Provisionierungsdatei muss mit dem Token der InfluxDB-Initialisierung übereinstimmen. Aktuell ist er statisch hinterlegt. Eine sichere Weiterentwicklung sollte den Token über eine geschützte Konfiguration oder Docker Secrets bereitstellen.

### 12.2 Dashboard-Provisionierung

Die Datenquelle ist im Repository provisioniert. Das eigentliche Dashboard wird derzeit in Grafana erstellt und im persistenten Volume gespeichert; ein Dashboard-Provider und eine exportierte Dashboard-JSON-Datei sind im aktuellen Repository noch nicht vorhanden.

Für einen vollständig reproduzierbaren Aufbau sollte das Dashboard später exportiert und beispielsweise so abgelegt werden:

```text
grafana/provisioning/
├── datasources/
│   └── influxdb.yml
└── dashboards/
    ├── dashboard.yml
    └── oxocard-dashboard.json
```

Damit wäre nach einem Neuaufbau nicht nur die Datenquelle, sondern auch das vollständige Dashboard automatisch verfügbar.

## 13. Aufbau des Grafana-Dashboards

Das Dashboard ist so konzipiert, dass zuerst der aktuelle Zustand sichtbar ist und darunter die zeitliche Entwicklung sowie die Rohdaten analysiert werden können.

```text
┌────────────────┬────────────────┬────────────────┬────────────────┐
│ Temperatur     │ Luftfeuchte    │ Luftdruck      │ Helligkeit     │
│ aktueller Wert │ aktueller Wert │ aktueller Wert │ aktueller Wert │
└────────────────┴────────────────┴────────────────┴────────────────┘
┌───────────────────────────────────────────────────────────────────┐
│ Temperaturverlauf                                                │
├───────────────────────────────────────────────────────────────────┤
│ Verlauf der Luftfeuchtigkeit                                     │
├───────────────────────────────────────────────────────────────────┤
│ Luftdruckverlauf                                                 │
├───────────────────────────────────────────────────────────────────┤
│ Helligkeitsverlauf                                               │
├───────────────────────────────────────────────────────────────────┤
│ Tabelle der Rohmesswerte                                         │
└───────────────────────────────────────────────────────────────────┘
```

### 13.1 Gemeinsames Abfragemuster

Alle Panels filtern nach Bucket, Measurement und Gerät. Grafanas Variable `v.timeRangeStart` übernimmt den im Dashboard gewählten Zeitraum.

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
```

Für Zeitreihen kann zusätzlich eine Fensteraggregation verwendet werden. Sie begrenzt bei langen Zeiträumen die Anzahl dargestellter Punkte:

```flux
|> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

### 13.2 Stat-Panels: aktuelle Werte

Die oberste Zeile enthält vier **Stat-Panels**. Sie beantworten die Frage: «Wie ist der aktuelle Zustand?» Für jedes Field wird der letzte Wert des gewählten Zeitraums ermittelt.

Beispiel für Temperatur:

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => r._field == "temperature")
  |> last()
```

Für die übrigen Panels wird nur `_field` angepasst:

| Panel | Field | Einheit |
|---|---|---|
| Aktuelle Temperatur | `temperature` | °C |
| Aktuelle Luftfeuchtigkeit | `humidity` | % |
| Aktueller Luftdruck | `pressure` | hPa |
| Aktuelle Helligkeit | `brightness` | lx |

Sinnvolle Grenzwerte können die Werte farblich kennzeichnen. Diese Schwellen dienen der visuellen Orientierung und müssen fachlich definiert werden; sie sind keine kalibrierten Alarmgrenzen.

### 13.3 Temperaturverlauf

**Visualisierung:** Time series
**Field:** `temperature`
**Einheit:** Grad Celsius (°C)

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => r._field == "temperature")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

Das Panel zeigt Erwärmung, Abkühlung und kurzfristige Schwankungen. Durch den gemeinsamen Dashboard-Zeitraum können beispielsweise die letzte Stunde, die letzten 24 Stunden oder mehrere Tage verglichen werden.

### 13.4 Verlauf der Luftfeuchtigkeit

**Visualisierung:** Time series
**Field:** `humidity`
**Einheit:** Prozent (%)

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => r._field == "humidity")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

Die Darstellung macht Veränderungen der relativen Luftfeuchtigkeit sichtbar und erlaubt den Vergleich mit der Temperatur. Eine spätere gemeinsame Visualisierung oder Korrelation kann zeigen, ob sich beide Grössen gegenseitig beeinflussen.

### 13.5 Luftdruckverlauf

**Visualisierung:** Time series
**Field:** `pressure`
**Einheit:** Hektopascal (hPa)

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => r._field == "pressure")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

Da sich der Luftdruck typischerweise langsamer verändert als andere Werte, ist eine passende Y-Achsen-Skalierung wichtig. Eine zu grosse Skala würde kleine, aber relevante Änderungen optisch verbergen.

### 13.6 Helligkeitsverlauf

**Visualisierung:** Time series
**Field:** `brightness`
**Einheit:** Lux (lx)

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => r._field == "brightness")
  |> aggregateWindow(every: v.windowPeriod, fn: mean, createEmpty: false)
```

Das Panel zeigt Beleuchtungswechsel, Tag-Nacht-Verläufe oder eine Abdeckung des Sensors. Da Helligkeit sprunghaft wechseln kann, ist neben dem Mittelwert je nach Analyse auch `max` oder `last` als Aggregation sinnvoll.

### 13.7 Rohdatentabelle

**Visualisierung:** Table
**Zweck:** Kontrolle einzelner Zeitstempel und Messwerte

```flux
from(bucket: "sensor_data")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
  |> filter(fn: (r) => contains(
      value: r._field,
      set: ["temperature", "humidity", "pressure", "brightness"]
  ))
  |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "device", "temperature", "humidity", "pressure", "brightness"])
  |> sort(columns: ["_time"], desc: true)
```

`pivot()` stellt die vier Fields als eigene Spalten dar. Dadurch steht pro Zeitstempel eine verständliche Tabellenzeile zur Verfügung. Die Tabelle ist insbesondere für Plausibilitätsprüfungen, Fehlersuche und Präsentationsnachweise nützlich.

### 13.8 Dashboard-Einstellungen

Empfohlene Einstellungen:

- Standardzeitraum: letzte Stunde
- automatische Aktualisierung: 5 bis 10 Sekunden
- Zeitzone: Browser oder Europe/Zurich
- Datenquelle: `InfluxDB` mit UID `influxdb`
- einheitliche Paneltitel und Einheiten
- Gerätefilter als Dashboard-Variable bei mehreren Oxocards

## 14. Installation und Inbetriebnahme

### 14.1 Voraussetzungen

Auf dem Hostsystem werden benötigt:

- Git
- Vagrant ab Version 2.4
- VirtualBox oder Parallels als VM-Provider
- mindestens 4 GB freier Arbeitsspeicher für die VM
- Netzwerkzugriff für das Herunterladen von Box und Container-Images
- Oxocard Science+ im gleichen erreichbaren Netzwerk

### 14.2 Projekt vorbereiten

```bash
git clone <REPOSITORY-URL>
cd InfluxDB-Oxocard-Project
```

Da es sich um eine isolierte Test- und Schulungsumgebung handelt, wird die Datei `.env` mit den benötigten Demo-Zugangsdaten im Repository mitgeführt. Nach dem Klonen ist deshalb keine zusätzliche Erstellung der Datei erforderlich.

Die Konfiguration enthält folgende Werte:

```dotenv
INFLUXDB_USERNAME=admin
INFLUXDB_PASSWORD=admin12345
INFLUXDB_ORG=TEKO
INFLUXDB_BUCKET=sensor_data
INFLUXDB_ADMIN_TOKEN=teko-database-design-token
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=admin12345
```

Der Token in `.env`, in `grafana/provisioning/datasources/influxdb.yml` und im Oxocard-Programm muss übereinstimmen. Im aktuellen Entwicklungsstand erfolgt diese Abstimmung manuell. Die mitgelieferten Zugangsdaten sind ausschliesslich für diese Testumgebung vorgesehen und dürfen nicht für andere Systeme wiederverwendet werden. Für eine produktive oder öffentlich erreichbare Installation müssten `.env` und Tokens aus der Versionsverwaltung entfernt und durch ein geeignetes Secret Management ersetzt werden. Die Datei `.env.example` bleibt als Vorlage für abweichende lokale Konfigurationen bestehen.

### 14.3 VM starten

```bash
cd database-vm
vagrant up --provider=virtualbox
```

Alternativ mit Parallels:

```bash
vagrant up --provider=parallels
```

Beim ersten Start werden die VM erstellt, Systempakete installiert, Docker eingerichtet und die Container gestartet. Dieser Vorgang dauert länger als ein normaler Neustart.

### 14.4 Dienste öffnen

Nach erfolgreichem Start sind die Oberflächen auf dem Host erreichbar:

| Dienst | Adresse |
|---|---|
| Grafana | `http://localhost:3000` |
| InfluxDB | `http://localhost:8086` |

Die private VM-Adresse lautet `192.168.56.10`. Ob die Oxocard diese direkt erreichen kann, hängt vom verwendeten Netzwerk und Provider ab. In der vorhandenen Oxocard-Konfiguration wird eine LAN-Adresse des Hostsystems verwendet. Diese Adresse muss an die lokale Umgebung angepasst werden.

### 14.5 Oxocard konfigurieren

Im Oxocard-Programm sind folgende Werte zu prüfen:

- erreichbare IP-Adresse und Port von InfluxDB
- Organisation `TEKO`
- Bucket `sensor_data`
- gültiger Token mit Schreibberechtigung
- Gerätename `oxocard01`
- Sendeintervall von 5000 ms

Danach wird das Programm auf die Oxocard übertragen und gestartet. Auf dem Display beziehungsweise in der seriellen Ausgabe muss `Upload successful` oder `Connected` erscheinen.

### 14.6 Daten prüfen

In der InfluxDB-Oberfläche kann mit einer einfachen Flux-Abfrage geprüft werden, ob Daten vorhanden sind:

```flux
from(bucket: "sensor_data")
  |> range(start: -15m)
  |> filter(fn: (r) => r._measurement == "environment")
  |> filter(fn: (r) => r.device == "oxocard01")
```

Anschliessend wird Grafana geöffnet. Unter **Connections → Data sources** sollte die automatisch eingerichtete Datenquelle `InfluxDB` sichtbar sein.

## 15. Betrieb und Kontrolle

### 15.1 Status der VM

```bash
cd database-vm
vagrant status
```

### 15.2 Status der Container

```bash
vagrant ssh
cd /project
docker compose ps
```

### 15.3 Logs anzeigen

```bash
docker compose logs --tail=100 influxdb
docker compose logs --tail=100 grafana
```

### 15.4 Stack neu starten

```bash
docker compose restart
```

### 15.5 VM beenden und erneut starten

```bash
vagrant halt
vagrant up
```

Die Container sollten dank `restart: unless-stopped` automatisch wieder starten. Falls Konfigurationsdateien geändert wurden, kann der Stack in `/project` erneut angewendet werden:

```bash
docker compose up -d --remove-orphans
```

### 15.6 Neu provisionieren

```bash
vagrant provision
```

Ein vollständiges Löschen der VM mit `vagrant destroy` entfernt die virtuelle Maschine. Persistente Docker-Volumes innerhalb dieser VM gehen dabei ebenfalls verloren. Dieser Schritt darf deshalb nur erfolgen, wenn die Daten entbehrlich oder gesichert sind.

## 16. Screenshots und Nachweise

Für die Abgabe und Präsentation sollten die folgenden Abbildungen ergänzt werden. Empfohlen wird ein Verzeichnis `docs/images/` mit aussagekräftigen Dateinamen.

> **Screenshot-Platzhalter 1:** Oxocard Science+ mit den vier aktuellen Sensorwerten und dem Status «Connected»
> Empfohlene Datei: `docs/images/oxocard-display.jpg`

> **Screenshot-Platzhalter 2:** laufende InfluxDB- und Grafana-Container
> Empfohlene Datei: `docs/images/docker-compose-status.png`

> **Screenshot-Platzhalter 3:** InfluxDB Data Explorer mit Messwerten aus `sensor_data`
> Empfohlene Datei: `docs/images/influxdb-data-explorer.png`

> **Screenshot-Platzhalter 4:** automatisch provisionierte InfluxDB-Datenquelle in Grafana
> Empfohlene Datei: `docs/images/grafana-datasource.png`

> **Screenshot-Platzhalter 5:** vollständiges Oxocard-Dashboard mit Stat-Panels, vier Zeitreihen und Rohdatentabelle
> Empfohlene Datei: `docs/images/grafana-dashboard.png`

> **Screenshot-Platzhalter 6:** Detailansicht eines Time-Series-Panels mit Flux-Abfrage
> Empfohlene Datei: `docs/images/grafana-flux-query.png`

Jeder Screenshot sollte in der finalen Projektdokumentation eine Bildnummer, eine kurze Bildlegende und einen Verweis im Fliesstext erhalten.

## 17. Herausforderungen und Erkenntnisse

### 18.1 Erreichbarkeit über mehrere Netzwerkebenen

Die Oxocard, das Hostsystem, die Vagrant-VM und die Docker-Container befinden sich in unterschiedlichen Netzwerkkontexten. Eine Adresse, die auf dem Host funktioniert, ist nicht automatisch von der Oxocard erreichbar. Die wichtigste Erkenntnis ist, die Verbindung schrittweise zu testen: InfluxDB-Healthcheck, Zugriff vom Host und zuletzt Zugriff aus dem WLAN der Oxocard.

### 18.2 Startreihenfolge der Container

Ein gestarteter Container ist noch nicht zwingend betriebsbereit. InfluxDB benötigt beim ersten Start Zeit für Organisation, Bucket und Benutzer. Der Healthcheck zusammen mit `condition: service_healthy` reduziert Fehler beim Grafana-Start. Gleichzeitig ist zu beachten, dass der Healthcheck von einem im Image verfügbaren HTTP-Werkzeug abhängt.

### 18.3 Abstimmung der Zugangsdaten

InfluxDB, Grafana und Oxocard müssen denselben Organisationsnamen, Bucket und passenden Token verwenden. Derzeit ist der Token an mehreren Stellen hinterlegt. Das ist fehleranfällig und sicherheitstechnisch nur für eine isolierte Lernumgebung vertretbar.

### 18.4 Tags und Fields

Die Unterscheidung ist für die Qualität des Datenmodells zentral. Tags verbessern Filterabfragen, erhöhen bei zu vielen eindeutigen Kombinationen jedoch die Kardinalität. Kontinuierliche Sensorwerte werden deshalb als Fields und der Gerätename als Tag gespeichert.

### 18.5 Grafana-Provisionierung

Eine automatisch eingerichtete Datenquelle ist noch kein vollständig reproduzierbares Dashboard. Manuell in Grafana erstellte Panels bleiben zwar im Volume erhalten, sind aber nicht als Code im Repository sichtbar. Der Export und die Provisionierung des Dashboard-JSON sind deshalb ein wichtiger nächster Schritt.

### 18.6 Zeitstempel und Datenverluste

Die serverseitige Zeitvergabe ist einfach, bildet bei Verbindungsunterbrüchen aber nicht den exakten Messzeitpunkt ab. Da die Oxocard fehlgeschlagene Uploads aktuell nicht puffert, entstehen in solchen Fällen Lücken. Für Messanwendungen mit Nachweispflicht wären lokale Warteschlange, Wiederholungslogik und synchronisierte Gerätezeit nötig.

### 18.7 Sensorqualität

Die Messwerte sind für einen technischen Prototyp geeignet, sollten aber nicht ohne Kalibrierung als Referenzmessung interpretiert werden. Besonders die Temperatur kann durch Eigenerwärmung des Geräts oder den Installationsort beeinflusst werden.

## 18. Projektstatus

### Infrastruktur

- [x] Vagrant-Umgebung erstellt
- [x] Ubuntu-VM provisioniert
- [x] Docker und Docker Compose automatisiert installiert
- [x] InfluxDB und Grafana containerisiert
- [x] persistente Volumes konfiguriert
- [x] InfluxDB-Healthcheck und Startabhängigkeit eingerichtet
- [x] Grafana-Datenquelle provisioniert

### Datenbankdesign und Datenerfassung

- [x] Forschungsfrage definiert
- [x] Bucket, Measurement, Tags und Fields modelliert
- [x] Oxocard mit WLAN verbunden
- [x] HTTP-Kommunikation getestet
- [x] vier Umgebungswerte in einem Datenpunkt übertragen
- [x] periodischer Versand im Fünf-Sekunden-Intervall umgesetzt
- [ ] Retention-Dauer fachlich festlegen
- [ ] Last-, Speicher- und Langzeitevaluation durchführen

### Visualisierung

- [x] InfluxDB als Grafana-Datenquelle verfügbar
- [x] Panelkonzept und Flux-Abfragen dokumentiert
- [ ] Dashboard als JSON exportieren und automatisch provisionieren
- [ ] finale Screenshots in die Dokumentation einfügen

## 19. Ausblick

Das Projekt kann in mehreren Richtungen erweitert werden:

1. **Dashboard als Code:** Dashboard-JSON exportieren, versionieren und beim Grafana-Start automatisch laden.
2. **Retention und Downsampling:** Rohdaten nur begrenzt aufbewahren und langfristig verdichtete Stunden- oder Tageswerte speichern.
3. **Mehrere Geräte:** zusätzliche Oxocards über den Tag `device` integrieren und in Grafana auswählbar machen.
4. **Zusätzliche Metadaten:** Raum und Standort als kontrollierte Tags ergänzen.
5. **Weitere Sensoren:** beispielsweise CO₂, Feinstaub oder Bewegungsdaten in geeigneten Measurements erfassen.
6. **Alarmierung:** Grenzwerte definieren und Benachrichtigungen über E-Mail oder Kollaborationsplattformen versenden.
7. **Sichere Kommunikation:** HTTPS, Reverse Proxy und Zertifikate einsetzen.
8. **Secret Management:** Tokens und Passwörter aus den Quell- und Provisionierungsdateien entfernen.
9. **Robustere Übertragung:** lokale Pufferung, Retry mit Backoff und eigene Zeitstempel implementieren.
10. **Datenqualität:** Sensoren kalibrieren, Ausreisser erkennen und fehlende Messungen sichtbar machen.
11. **Performance-Evaluation:** Schreiblast, Antwortzeiten, Speicherverbrauch und Kardinalität mit mehreren Geräten messen.
12. **Alternative Übertragung:** MQTT mit einem Broker prüfen, wenn viele Geräte oder instabile Verbindungen unterstützt werden sollen.
13. **Backup und Restore:** Sicherungs- und Wiederherstellungsverfahren für InfluxDB und Grafana dokumentieren und testen.

## 20. Fazit

Im Rahmen dieses Projekts wurde eine vollständige IoT-Zeitreihenpipeline konzipiert und in wesentlichen Teilen umgesetzt. Die Oxocard Science+ erfasst vier Umgebungsgrössen und überträgt sie regelmässig per HTTP an InfluxDB. Das Datenmodell trennt den indexierten Gerätebezug von den kontinuierlich wechselnden Messwerten und bleibt dadurch verständlich sowie erweiterbar.

InfluxDB eignet sich aufgrund seines Zeitreihenmodells und seiner HTTP-Schnittstelle gut für die Speicherung. Grafana ergänzt die Lösung um eine übersichtliche Darstellung aktueller Werte, historischer Verläufe und Rohdaten. Docker Compose sorgt für klar definierte Dienste, während Vagrant die zugrunde liegende Serverumgebung reproduzierbar bereitstellt.

Der Prototyp beantwortet die Forschungsfrage dahingehend, dass ein schlankes Modell mit einem gemeinsamen Bucket, einem fachlich passenden Measurement, wenigen kontrollierten Tags und numerischen Fields eine gute Grundlage für effiziente IoT-Auswertungen bildet. Gleichzeitig zeigt das Projekt, dass ein zuverlässiges Gesamtsystem mehr als die Datenbank allein umfasst: Netzwerkzugriff, Startreihenfolge, Authentifizierung, Zeitstempel, Persistenz und reproduzierbare Dashboards sind ebenso entscheidend.

Mit Dashboard-Provisionierung, definierter Retention, sicherem Secret Management und einer systematischen Performance-Evaluation kann die Lösung zu einer belastbaren Plattform für Smart-Building-, Umweltmonitoring- oder Industrie-4.0-Anwendungen weiterentwickelt werden.
