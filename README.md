# Datalogic Firmware Update Tool

Bash script voor het updaten van Datalogic handheld devices via ADB.

**Platform:** macOS / Linux

## Ondersteunde devices

Het script werkt met alle Datalogic Android devices die ADB ondersteunen, inclusief oudere modellen.

**Devices met sideload ondersteuning:**
- Memor 11, 12, 17, 20, 30, 35
- Skorpio X5
- Joya Touch 22

**Oudere devices** (update via service, broadcast of handmatig):
- Memor 1, 10
- Skorpio X3, X4
- Joya Touch / Joya Touch A6
- Falcon X3, X4
- En andere Datalogic Android handhelds

## Vereisten

- **ADB** (Android Debug Bridge)
- **qrencode** (optioneel, voor QR code weergave bij provisioning)

### Installatie vereisten (macOS)

```bash
# ADB via Homebrew
brew install android-platform-tools

# QR code tool (optioneel)
brew install qrencode
```

### Installatie vereisten (Linux)

```bash
# Debian/Ubuntu
sudo apt install adb qrencode

# Fedora
sudo dnf install android-tools qrencode
```

## Gebruik

```bash
./datalogic-update.sh
```

Het script begeleidt je interactief door het update proces.

## Update methodes

| Methode | Beschrijving | Geschikt voor |
|---------|--------------|---------------|
| **Sideload** | Firmware direct vanaf PC via recovery mode | Memor 11/12/17/20/30/35, Skorpio X5, Joya Touch 22 |
| **Systeem service** | Via Datalogic SystemUpdate service | Android 9 |
| **Broadcast intent** | Via Android broadcast | Android 10+ |
| **Alleen kopieren** | Handmatige update via instellingen | Android 8 → 9 upgrades |

## Reset opties

Bij service/broadcast methodes kun je kiezen uit:

- **Geen reset** - Behoud alle data
- **Factory reset** - Wist alles inclusief enterprise configuratie
- **Enterprise reset** - Wist gebruikersdata, behoudt enterprise configuratie

## Provisioning (geen ADB verbinding)

Als het device niet via ADB bereikbaar is:

1. Voer een Factory Reset uit via Instellingen
2. Op het blauwe Android setup scherm: scan de QR code die het script toont

## Troubleshooting

**Device niet gevonden**
- Controleer USB verbinding
- Controleer of USB debugging aan staat op het device
- Autoriseer de computer op het device indien gevraagd

**Sideload mislukt**
- Sommige devices vereisen root voor sideload mode
- Gebruik in dat geval methode 2 of 3

**Signature error bij firmware**
- Zorg dat de originele bestandsnaam behouden blijft
- Hernoem het firmware bestand niet
