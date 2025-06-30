# AIGentics Germany Server Setup

Diese Anleitung beschreibt die Einrichtung eines Hetzner Cloud Servers für AIGentics Germany mit E-Mail-Server, HTTPS und automatischen Updates.

## Übersicht

- **Server**: Hetzner CX22 (€3.79/Monat)
- **Betriebssystem**: Ubuntu 22.04 LTS
- **Services**: 
  - Traefik (Reverse Proxy mit Let's Encrypt)
  - Poste.io (E-Mail-Server)
  - Nginx (Webserver)
  - Watchtower (Auto-Updates)

## Schritt 1: Server bei Hetzner bestellen

1. Gehen Sie zu [console.hetzner.com](https://console.hetzner.com)
2. Erstellen Sie einen neuen Server:
   - **Typ**: CX22 (2 vCPU, 4 GB RAM, 40 GB SSD)
   - **Standort**: Nürnberg oder Falkenstein
   - **Image**: Ubuntu 22.04
   - **SSH-Key**: Laden Sie Ihren öffentlichen SSH-Key hoch
   - **Cloud Config**: Kopieren Sie den Inhalt von `cloud-config.yaml`

## Schritt 2: DNS-Einstellungen bei united-domains.de

Nachdem Sie die Server-IP erhalten haben, konfigurieren Sie folgende DNS-Einträge:

| Typ  | Name      | Wert                                          |
|------|-----------|-----------------------------------------------|
| A    | @         | [Server-IP]                                   |
| A    | mail      | [Server-IP]                                   |
| A    | traefik   | [Server-IP]                                   |
| MX   | @         | 10 mail.aigentics-germany.de                 |
| TXT  | @         | "v=spf1 ip4:[Server-IP] ~all"               |
| TXT  | _dmarc    | "v=DMARC1; p=none; rua=mailto:postmaster@aigentics-germany.de" |

**Hinweis**: Die DKIM-Einträge werden nach der Poste.io-Einrichtung hinzugefügt.

## Schritt 3: Server-Einrichtung

1. Verbinden Sie sich per SSH mit dem Server:
   ```bash
   ssh root@[Server-IP]
   ```

2. Warten Sie, bis cloud-init fertig ist (ca. 5-10 Minuten):
   ```bash
   cloud-init status --wait
   ```

3. Klonen Sie das Repository:
   ```bash
   git clone https://github.com/patrickjaja/aigentics-germany.git
   cd aigentics-germany/infrastructure/hetzner
   ```

4. Kopieren Sie die Dateien und führen Sie das Setup aus:
   ```bash
   cp -r * /opt/docker/
   cd /opt/docker
   ./setup-docker.sh
   ```

## Schritt 4: Poste.io E-Mail-Server einrichten

1. Öffnen Sie: `https://mail.aigentics-germany.de`
2. Führen Sie den Setup-Wizard aus:
   - Admin E-Mail: `patrick.schoenfeld@aigentics-germany.de`
   - Wählen Sie ein sicheres Passwort
   - Zeitzone: Europe/Berlin

3. Nach der Einrichtung, konfigurieren Sie die E-Mail-Weiterleitung:
   - Melden Sie sich im Admin-Panel an
   - Gehen Sie zu: Virtual Domains → aigentics-germany.de
   - Klicken Sie auf Mailboxes → patrick.schoenfeld
   - Aktivieren Sie "Forward to" und geben Sie ein: `aigentics.germany@gmail.com`

4. DKIM einrichten:
   ```bash
   /root/configure-dns.sh
   ```
   Fügen Sie den angezeigten DKIM-Eintrag bei united-domains.de hinzu.

## Schritt 5: E-Mail-Client konfigurieren

Verwenden Sie diese Einstellungen für Ihr Smartphone oder E-Mail-Programm:

**Ausgangsserver (SMTP):**
- Server: `mail.aigentics-germany.de`
- Port: `587`
- Sicherheit: `STARTTLS`
- Benutzername: `patrick.schoenfeld@aigentics-germany.de`
- Passwort: [Ihr Poste.io Passwort]

**Eingangsserver (IMAP):**
- Server: `mail.aigentics-germany.de`
- Port: `993`
- Sicherheit: `SSL/TLS`
- Benutzername: `patrick.schoenfeld@aigentics-germany.de`
- Passwort: [Ihr Poste.io Passwort]

## Webseite verwalten

Die Webseiten-Dateien befinden sich in: `/opt/docker/nginx/html/`

Um Dateien hochzuladen:
```bash
scp ihre-datei.html root@[Server-IP]:/opt/docker/nginx/html/
```

## Sicherheit

Das System ist mit folgenden Sicherheitsmaßnahmen konfiguriert:
- UFW Firewall (nur benötigte Ports offen)
- Fail2ban (Schutz vor Brute-Force-Angriffen)
- Automatische Sicherheitsupdates
- Let's Encrypt SSL-Zertifikate

## Wartung

- **Container-Updates**: Watchtower aktualisiert alle Container täglich um 4 Uhr morgens
- **System-Updates**: Unattended-upgrades installiert Sicherheitsupdates automatisch
- **Logs anzeigen**: `docker compose logs -f [service-name]`
- **Services neustarten**: `docker compose restart [service-name]`

## Zugangsdaten

Alle Zugangsdaten finden Sie in: `/root/server-credentials.txt`

## Troubleshooting

**E-Mails kommen nicht an:**
1. Prüfen Sie die DNS-Einträge: `dig MX aigentics-germany.de`
2. Prüfen Sie die Logs: `docker compose logs -f poste`
3. Testen Sie die Weiterleitung im Poste.io Admin-Panel

**SSL-Zertifikat-Probleme:**
1. Prüfen Sie die DNS-Auflösung: `dig A aigentics-germany.de`
2. Prüfen Sie Traefik-Logs: `docker compose logs -f traefik`
3. Löschen Sie acme.json und starten Sie neu: `rm traefik/acme.json && docker compose restart traefik`

**Server nicht erreichbar:**
1. Prüfen Sie die Firewall: `ufw status`
2. Prüfen Sie Docker: `docker compose ps`
3. Prüfen Sie die Server-IP: `curl ifconfig.me`