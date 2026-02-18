#!/usr/bin/env bash

# ==========================================
# KONFIGURASI
# ==========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP_FILE="$SCRIPT_DIR/ip.profile"
OUT_FILE="$SCRIPT_DIR/$(date +%Y%m%d).csv"

# SNMP OIDs
OID_NE="SNMPv2-SMI::enterprises.2544.1.11.2.2.1.1.0"
OID_PORT="SNMPv2-SMI::enterprises.2544.1.11.7.2.3.1.6"
OID_ALIAS="SNMPv2-SMI::enterprises.2544.1.11.7.3.5.3.1.4"
OID_RX="SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.2"
OID_RXATT="SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.11"
OID_TX="SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.1"
OID_TXATT="SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.10"

# Settings
COMMUNITY="public"
TIMEOUT_SEC=1
RETRIES=1

# ==========================================
# FUNGSI BANTUAN (DIPERBAIKI)
# ==========================================

# Fungsi Ping Kompatibel
check_alive() {
    local target_ip=$1
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        ping -n 1 -w 1000 "$target_ip" &> /dev/null
    else
        ping -c 1 -W 1 "$target_ip" &> /dev/null
    fi
}

# Fungsi Format Angka (DIPERBAIKI: Menangani 1 digit menjadi 0.x)
format_snmp_value() {
    local raw_output="$1"
    
    # Cek apakah output mengandung error atau kosong
    if [[ -z "$raw_output" || "$raw_output" == *"No Such Instance"* || "$raw_output" == *"No Such Object"* ]]; then
        echo ""
        return
    fi

    # Bersihkan output SNMP
    local val=$(echo "$raw_output" | sed -e 's/.*INTEGER: //' -e 's/.*STRING: //' -e 's/"//g' -e 's/^[ \t]*//')

    # Logika Matematika/Teks: Memastikan format desimal
    if [[ "$val" =~ ^-?[0-9]+$ ]]; then
        if [[ ${#val} -eq 1 ]]; then
            # Kasus 1 digit: 8 -> 0.8, 0 -> 0.0
            echo "0.$val"
        else
            # Kasus >1 digit: 27 -> 2.7, -15 -> -1.5
            local int_part=${val::-1}
            local dec_part=${val: -1}
            echo "$int_part.$dec_part"
        fi
    else
        echo "$val"
    fi
}

# Fungsi Clean String (DIPERBAIKI: Menangani input kosong)
clean_string() {
    local raw_output="$1"
    if [[ -z "$raw_output" || "$raw_output" == *"No Such Instance"* || "$raw_output" == *"No Such Object"* ]]; then
        echo ""
        return
    fi
    echo "$raw_output" | sed -e 's/.*STRING: //' -e 's/"//g' -e 's/^[ \t]*//'
}

# ==========================================
# MAIN PROGRAM
# ==========================================

# Cek dependensi
if ! command -v snmpwalk &> /dev/null; then
    echo "Error: 'snmpwalk' belum terinstall."
    exit 1
fi

# Header CSV
echo "DATE|IP|NE|PORT|ALIAS|Rx(dBm)|Rx Att(db)|Tx(dBm)|Tx Att(db)" > "$OUT_FILE"

if [ ! -f "$IP_FILE" ]; then
    echo "Error: File $IP_FILE tidak ditemukan."
    exit 1
fi

echo "Output: $OUT_FILE"
echo "Processing..."

# Baca IP
grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" "$IP_FILE" | while read -r IP; do
    
    # Cek Koneksi
    if check_alive "$IP"; then
        STATUS_MSG="\e[32mAlive\e[0m"
        IS_ALIVE=true
    else
        STATUS_MSG="\e[31mTime Out\e[0m"
        IS_ALIVE=false
    fi

    printf "IP: %-15s [%b]" "$IP" "$STATUS_MSG"

    if [ "$IS_ALIVE" = false ]; then
        echo -e "$(date +%d/%m/%Y)|$IP|||||||" >> "$OUT_FILE"
        echo ""
        continue
    fi

    # Ambil NE Name
    RAW_NE=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_NE" 2>/dev/null)
    NENAME=$(clean_string "$RAW_NE")

    # Ambil List Index Port (Filter NE/NW/OSC)
    ID_LIST=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_PORT" 2>/dev/null \
              | grep "NE\|NW\|OSC" | grep "STRING" \
              | cut -d'=' -f1 | awk -F'.' '{print $(NF-4)"."$(NF-3)"."$(NF-2)"."$(NF-1)"."$(NF)}')

    COUNT=0
    for k in $ID_LIST; do
        # Ambil Data
        RAW_PORT=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_PORT.$k" 2>/dev/null)
        PORTNAME=$(clean_string "$RAW_PORT")
        
        RAW_ALIAS=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_ALIAS.$k" 2>/dev/null)
        ALIASNAME=$(clean_string "$RAW_ALIAS")

        RAW_RX=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_RX.$k" 2>/dev/null)
        RXLEV=$(format_snmp_value "$RAW_RX")

        RAW_RXATT=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_RXATT.$k" 2>/dev/null)
        RXATT=$(format_snmp_value "$RAW_RXATT")

        RAW_TX=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_TX.$k" 2>/dev/null)
        TXLEV=$(format_snmp_value "$RAW_TX")

        RAW_TXATT=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_TXATT.$k" 2>/dev/null)
        TXATT=$(format_snmp_value "$RAW_TXATT")

        # Tulis ke CSV
        if [[ -n "$PORTNAME" || -n "$RXLEV" || -n "$TXLEV" ]]; then
            CURRENT_DATE=$(date +%d/%m/%Y)
            echo "$CURRENT_DATE|$IP|$NENAME|$PORTNAME|$ALIASNAME|$RXLEV|$RXATT|$TXLEV|$TXATT" >> "$OUT_FILE"
            ((COUNT++))
        fi
        
    done

    echo -e " -> \e[33m$COUNT ports\e[0m"

done

echo "Done."
