#!/bin/bash

# Datalogic Device Firmware Update Script
# ========================================

# Kleuren voor output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

DEVICE_FIRMWARE_DIR="/sdcard/"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Datalogic Firmware Update Tool${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Stap 1: Detecteer beschikbare devices
echo -e "${YELLOW}Zoeken naar verbonden ADB devices...${NC}"
DEVICES=$(adb devices | grep -v "List of devices" | grep -v "^$" | awk '{print $1}')

if [ -z "$DEVICES" ]; then
    echo -e "${RED}Geen ADB devices gevonden!${NC}"
    echo ""
    echo "Als het device niet bereikbaar is via ADB:"
    echo "  1. Voer een Factory Reset uit via Instellingen"
    echo "  2. Scan onderstaande QR code op het blauwe Android scherm"
    echo ""

    # QR code data voor device provisioning
    QR_DATA="~0101Bm9uiYcW/dWOnA0ZtIrgLXqxlj8DXbV4pKMGk9m+mZoD4Bpth4KUWN0s5p+1rahTT+SOYvWDCPud80MRyPWVBWAW+EQqTtm294xij//XY95YqelDqsWCLMTxmBUC27g5F0pQtHGEtUEzmlO7C3rdYMeltTjddqaS23eRnaCJnsieB3pgtBB9p+SZGJD5HChSD2RLj7xQWMxyuEcL0cwVJ2bHfBGPwvme0VGUuzfCJ7G+t+abrcEC5JQLOEfZFUUgFS9Plataz1lKjaN/vjg5qMl2fASPk+wxv5LhvZ+ElklI0XB1FPXtbNkFwh64aNVEu9SigF8W"

    # Controleer of qrencode beschikbaar is
    if command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}Provisioning QR Code:${NC}"
        echo ""
        qrencode -t ANSIUTF8 "$QR_DATA"
        echo ""
    else
        echo -e "${YELLOW}Installeer qrencode om de QR code te zien:${NC}"
        echo "  brew install qrencode"
        echo ""
        echo "QR Data (handmatig genereren):"
        echo "$QR_DATA"
    fi

    exit 1
fi

# Tel aantal devices
DEVICE_COUNT=$(echo "$DEVICES" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq 1 ]; then
    SELECTED_DEVICE="$DEVICES"
    echo -e "${GREEN}Device gevonden: ${SELECTED_DEVICE}${NC}"
else
    echo -e "${YELLOW}Meerdere devices gevonden:${NC}"
    i=1
    for device in $DEVICES; do
        echo "  $i) $device"
        i=$((i+1))
    done
    echo ""
    read -p "Selecteer device nummer: " DEVICE_NUM
    SELECTED_DEVICE=$(echo "$DEVICES" | sed -n "${DEVICE_NUM}p")
    echo -e "${GREEN}Geselecteerd: ${SELECTED_DEVICE}${NC}"
fi

# Haal device model op
DEVICE_MODEL=$(adb -s "$SELECTED_DEVICE" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
echo -e "${GREEN}Device type: ${DEVICE_MODEL}${NC}"

# Bepaal of device sideload ondersteunt
# Ondersteunde devices: Memor 11, Memor 20, SkorpioX5, Memor 30/35, Memor 12/17, Joya Touch 22
SIDELOAD_SUPPORTED="FALSE"
case "$DEVICE_MODEL" in
    *"MEMOR 11"*|*"Memor 11"*|*"MEMOR11"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"MEMOR 20"*|*"Memor 20"*|*"MEMOR20"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"MEMOR 30"*|*"Memor 30"*|*"MEMOR30"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"MEMOR 35"*|*"Memor 35"*|*"MEMOR35"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"MEMOR 12"*|*"Memor 12"*|*"MEMOR12"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"MEMOR 17"*|*"Memor 17"*|*"MEMOR17"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"SKORPIO X5"*|*"Skorpio X5"*|*"SKORPIOX5"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
    *"JOYA TOUCH 22"*|*"Joya Touch 22"*|*"JT22"*)
        SIDELOAD_SUPPORTED="TRUE" ;;
esac

echo ""

# Stap 2: Update methode
echo -e "${YELLOW}Welke update methode?${NC}"
if [ "$SIDELOAD_SUPPORTED" == "TRUE" ]; then
    echo "  1) Sideload via recovery (firmware direct vanaf PC)"
    echo "  2) Via systeem service - OUDE methode (Android 9)"
    echo "  3) Via broadcast intent - NIEUWE methode (Android 10+)"
    echo "  4) Alleen kopieren (handmatig via menu, bijv. Android 8>9)"
    echo ""
    read -p "Keuze [1/2/3/4]: " UPDATE_METHOD
else
    echo "  1) Via systeem service - OUDE methode (Android 9)"
    echo "  2) Via broadcast intent - NIEUWE methode (Android 10+)"
    echo "  3) Alleen kopieren (handmatig via menu, bijv. Android 8>9)"
    echo ""
    read -p "Keuze [1/2/3]: " USER_CHOICE
    # Map keuzes naar interne methode nummers
    case $USER_CHOICE in
        1) UPDATE_METHOD="2" ;;  # Systeem service
        2) UPDATE_METHOD="3" ;;  # Broadcast
        3) UPDATE_METHOD="4" ;;  # Alleen kopieren
        *) UPDATE_METHOD="2" ;;
    esac
fi

echo ""

# Stap 3: Firmware locatie (afhankelijk van methode)
if [ "$UPDATE_METHOD" == "1" ] || [ "$UPDATE_METHOD" == "4" ]; then
    # Sideload of alleen kopieren: firmware moet vanaf PC komen
    echo -e "${YELLOW}Voer het volledige pad naar de firmware in:${NC}"
    echo "(Je kunt het bestand ook slepen naar dit venster)"
    read -p "Firmware pad: " FIRMWARE_PATH

    # Verwijder eventuele quotes en escaped spaces
    FIRMWARE_PATH=$(echo "$FIRMWARE_PATH" | sed "s/^'//" | sed "s/'$//" | sed 's/^"//' | sed 's/"$//' | sed 's/\\ / /g')

    # Controleer of bestand bestaat
    if [ ! -f "$FIRMWARE_PATH" ]; then
        echo -e "${RED}Bestand niet gevonden: ${FIRMWARE_PATH}${NC}"
        exit 1
    fi

    echo -e "${GREEN}Firmware gevonden: ${FIRMWARE_PATH}${NC}"
    FIRMWARE_CHOICE="1"
    # Behoud originele bestandsnaam (voorkomt signature errors)
    FIRMWARE_FILENAME=$(basename "$FIRMWARE_PATH")
    DEVICE_FIRMWARE_PATH="${DEVICE_FIRMWARE_DIR}${FIRMWARE_FILENAME}"
else
    # Service/Broadcast: firmware moet op device staan
    echo -e "${YELLOW}Firmware bron:${NC}"
    echo "  1) Nieuwe firmware uploaden vanaf PC"
    echo "  2) Firmware staat al op device (${DEVICE_FIRMWARE_DIR})"
    echo ""
    read -p "Keuze [1/2]: " FIRMWARE_CHOICE

    if [ "$FIRMWARE_CHOICE" == "1" ]; then
        echo ""
        echo -e "${YELLOW}Voer het volledige pad naar de firmware in:${NC}"
        echo "(Je kunt het bestand ook slepen naar dit venster)"
        read -p "Firmware pad: " FIRMWARE_PATH

        # Verwijder eventuele quotes en escaped spaces
        FIRMWARE_PATH=$(echo "$FIRMWARE_PATH" | sed "s/^'//" | sed "s/'$//" | sed 's/^"//' | sed 's/"$//' | sed 's/\\ / /g')

        # Controleer of bestand bestaat
        if [ ! -f "$FIRMWARE_PATH" ]; then
            echo -e "${RED}Bestand niet gevonden: ${FIRMWARE_PATH}${NC}"
            exit 1
        fi

        echo -e "${GREEN}Firmware gevonden: ${FIRMWARE_PATH}${NC}"
        # Behoud originele bestandsnaam (voorkomt signature errors)
        FIRMWARE_FILENAME=$(basename "$FIRMWARE_PATH")
        DEVICE_FIRMWARE_PATH="${DEVICE_FIRMWARE_DIR}${FIRMWARE_FILENAME}"
    else
        # Vraag naar bestandsnaam op device
        echo -e "${YELLOW}Welk firmware bestand op device?${NC}"
        echo "(Toon bestanden in ${DEVICE_FIRMWARE_DIR})"
        adb -s "$SELECTED_DEVICE" shell "ls -1 ${DEVICE_FIRMWARE_DIR}*.zip 2>/dev/null"
        echo ""
        read -p "Bestandsnaam (bijv. firmware.zip): " DEVICE_FILENAME
        DEVICE_FIRMWARE_PATH="${DEVICE_FIRMWARE_DIR}${DEVICE_FILENAME}"

        # Controleer of firmware op device staat
        echo -e "${YELLOW}Controleren of firmware aanwezig is op device...${NC}"
        adb -s "$SELECTED_DEVICE" shell "ls '$DEVICE_FIRMWARE_PATH'" > /dev/null 2>&1

        if [ $? -ne 0 ]; then
            echo -e "${RED}Firmware niet gevonden op ${DEVICE_FIRMWARE_PATH}${NC}"
            exit 1
        fi
        echo -e "${GREEN}Firmware gevonden op device${NC}"
    fi
fi

echo ""

# Stap 4: Factory reset vraag (niet bij sideload of alleen kopieren)
if [ "$UPDATE_METHOD" == "1" ]; then
    RESET_VALUE=0
    echo -e "${YELLOW}Let op: Bij sideload is factory reset niet mogelijk via dit script.${NC}"
elif [ "$UPDATE_METHOD" == "4" ]; then
    RESET_VALUE=0
    echo -e "${YELLOW}Firmware wordt gekopieerd. Update handmatig via: Instellingen > Systeem > Systeemupdates${NC}"
else
    echo -e "${YELLOW}Wil je een reset na de update?${NC}"
    echo "  0) Geen reset"
    echo "  1) Factory reset (wist alles incl. enterprise config)"
    echo "  2) Enterprise reset (wist gebruikersdata, behoudt enterprise config)"
    echo ""
    read -p "Keuze [0/1/2]: " RESET_CHOICE

    case $RESET_CHOICE in
        0) RESET_VALUE=0 ;;
        1) RESET_VALUE=1 ;;
        2) RESET_VALUE=2 ;;
        *) RESET_VALUE=0 ;;
    esac
fi

echo ""

# Stap 5: Bevestiging
METHOD_NAMES=("" "Sideload via recovery" "Systeem service" "Broadcast intent" "Alleen kopieren")
RESET_NAMES=("Geen reset" "Factory reset" "Enterprise reset")

echo -e "${YELLOW}Samenvatting:${NC}"
echo "  Device: $SELECTED_DEVICE ($DEVICE_MODEL)"
if [ "$UPDATE_METHOD" == "1" ]; then
    echo "  Firmware: $FIRMWARE_PATH (vanaf PC)"
else
    echo "  Firmware: $DEVICE_FIRMWARE_PATH (op device)"
fi
echo "  Methode: ${METHOD_NAMES[$UPDATE_METHOD]}"
echo "  Reset: ${RESET_NAMES[$RESET_VALUE]}"
echo ""
read -p "Update starten? [j/n]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[jJyY]$ ]]; then
    echo -e "${YELLOW}Update geannuleerd.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Update starten...${NC}"

case $UPDATE_METHOD in
    1)
        # Sideload via recovery
        echo -e "${YELLOW}Device herstarten naar sideload mode...${NC}"

        # Probeer reboot naar sideload
        REBOOT_OUTPUT=$(adb -s "$SELECTED_DEVICE" reboot sideload-auto-reboot 2>&1)

        if echo "$REBOOT_OUTPUT" | grep -q "root"; then
            echo -e "${RED}Dit device vereist root voor sideload mode.${NC}"
            echo -e "${RED}Root is niet beschikbaar op production builds.${NC}"
            echo -e "${YELLOW}Gebruik methode 2 of 3 in plaats van sideload.${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Wachten op sideload mode...${NC}"

        # Wacht max 60 seconden op sideload mode (macOS compatibel)
        COUNTER=0
        while [ $COUNTER -lt 60 ]; do
            if adb -s "$SELECTED_DEVICE" get-state 2>&1 | grep -q "sideload"; then
                break
            fi
            sleep 1
            COUNTER=$((COUNTER + 1))
        done

        if [ $COUNTER -ge 60 ]; then
            echo -e "${RED}Timeout: kon niet verbinden met sideload mode${NC}"
            echo -e "${YELLOW}Tip: Probeer update methode 2 of 3${NC}"
            exit 1
        fi

        echo -e "${GREEN}Device in sideload mode${NC}"
        echo -e "${YELLOW}Firmware sideloaden (dit kan enkele minuten duren)...${NC}"

        adb -s "$SELECTED_DEVICE" sideload "$FIRMWARE_PATH"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Sideload voltooid!${NC}"
        else
            echo -e "${RED}Sideload mislukt!${NC}"
            exit 1
        fi
        ;;

    2)
        # Via systeem service - eerst pushen indien nodig
        if [ "$FIRMWARE_CHOICE" == "1" ]; then
            echo -e "${YELLOW}Firmware uploaden naar device...${NC}"
            adb -s "$SELECTED_DEVICE" push "$FIRMWARE_PATH" "$DEVICE_FIRMWARE_PATH"

            if [ $? -ne 0 ]; then
                echo -e "${RED}Fout bij uploaden van firmware!${NC}"
                exit 1
            fi
            echo -e "${GREEN}Firmware geupload${NC}"
        fi

        echo -e "${YELLOW}Update via systeem service...${NC}"
        adb -s "$SELECTED_DEVICE" shell am startservice \
            -n com.datalogic.systemupdate/com.datalogic.systemupdate.SystemUpgradeService \
            --ei action 2 \
            -e path "$DEVICE_FIRMWARE_PATH" \
            --ei force_update 1 \
            --ei reset $RESET_VALUE

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Service commando verzonden${NC}"
        else
            echo -e "${RED}Service methode mislukt!${NC}"
            exit 1
        fi
        ;;

    3)
        # Via broadcast intent - eerst pushen indien nodig
        if [ "$FIRMWARE_CHOICE" == "1" ]; then
            echo -e "${YELLOW}Firmware uploaden naar device...${NC}"
            adb -s "$SELECTED_DEVICE" push "$FIRMWARE_PATH" "$DEVICE_FIRMWARE_PATH"

            if [ $? -ne 0 ]; then
                echo -e "${RED}Fout bij uploaden van firmware!${NC}"
                exit 1
            fi
            echo -e "${GREEN}Firmware geupload${NC}"
        fi

        echo -e "${YELLOW}Update via broadcast intent...${NC}"
        adb -s "$SELECTED_DEVICE" shell am broadcast \
            -a com.datalogic.systemupdate.action.FIRMWARE_UPDATE \
            -e path "$DEVICE_FIRMWARE_PATH" \
            --ei reset $RESET_VALUE \
            --ei reboot 1

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Broadcast commando verzonden${NC}"
        else
            echo -e "${RED}Broadcast methode mislukt!${NC}"
            exit 1
        fi
        ;;

    4)
        # Alleen kopieren - voor handmatige update (bijv. Android 8>9)
        echo -e "${YELLOW}Firmware uploaden naar device...${NC}"
        adb -s "$SELECTED_DEVICE" push "$FIRMWARE_PATH" "$DEVICE_FIRMWARE_PATH"

        if [ $? -ne 0 ]; then
            echo -e "${RED}Fout bij uploaden van firmware!${NC}"
            exit 1
        fi

        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Firmware gekopieerd!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "Bestand staat op: ${DEVICE_FIRMWARE_PATH}"
        echo ""
        echo -e "${YELLOW}Start de update handmatig via:${NC}"
        echo "  Instellingen > Systeem > Systeemupdates"
        echo "  of"
        echo "  Settings > System > System updates"
        exit 0
        ;;

    *)
        echo -e "${RED}Ongeldige methode${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Update commando verzonden!${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Het device zal nu de update starten."
echo "Koppel het device NIET los tijdens de update!"
