#!/usr/bin/env bash

# ==========================================
# KONFIGURASI
# ==========================================
# Perbaikan pada baris ini (tanda kurung ditutup dengan benar)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IP_FILE="$SCRIPT_DIR/ip.profile"
DEFAULT_FILE="$SCRIPT_DIR/default.csv"
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
THRESHOLD_DIFF=5   # Selisih kenaikan dibanding default.csv
THRESHOLD_MAX=32   # Nilai absolut maksimal RXATT

# ==========================================
# FUNGSI BANTUAN
# ==========================================

check_alive() {
    local target_ip=$1
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        ping -n 1 -w 1000 "$target_ip" &> /dev/null
    else
        ping -c 1 -W 1 "$target_ip" &> /dev/null
    fi
}

format_snmp_value() {
    local raw_output="$1"
    if [[ -z "$raw_output" || "$raw_output" == *"No Such Instance"* || "$raw_output" == *"No Such Object"* ]]; then
        echo ""
        return
    fi
    local val=$(echo "$raw_output" | sed -e 's/.*INTEGER: //' -e 's/.*STRING: //' -e 's/"//g' -e 's/^[ \t]*//')

    if [[ "$val" =~ ^-?[0-9]+$ ]]; then
        if [[ ${#val} -eq 1 ]]; then
            echo "0.$val"
        else
            local int_part=${val::-1}
            local dec_part=${val: -1}
            echo "$int_part.$dec_part"
        fi
    else
        echo "$val"
    fi
}

clean_string() {
    local raw_output="$1"
    if [[ -z "$raw_output" || "$raw_output" == *"No Such Instance"* || "$raw_output" == *"No Such Object"* ]]; then
        echo ""
        return
    fi
    echo "$raw_output" | sed -e 's/.*STRING: //' -e 's/"//g' -e 's/^[ \t]*//'
}

get_default_rxatt() {
    local ip=$1
    local port=$2
    if [ ! -f "$DEFAULT_FILE" ]; then
        echo ""
        return
    fi
    # Mencari nilai RXATT berdasarkan IP dan PORT di file default.csv (kolom ke-7)
    grep -F "|${ip}|" "$DEFAULT_FILE" | grep -F "|${port}|" | awk -F'|' '{print $7}' | head -n 1
}

# ==========================================
# MAIN PROGRAM
# ==========================================

# Cek dependensi snmpwalk dan bc
if ! command -v snmpwalk &> /dev/null; then
    echo "Error: 'snmpwalk' tidak ditemukan. Install net-snmp-utils."
    exit 1
fi
if ! command -v bc &> /dev/null; then
    echo "Error: 'bc' tidak ditemukan. Install bc untuk kalkulasi desimal."
    exit 1
fi

# Buat Header CSV
echo "DATE|IP|NE|PORT|ALIAS|Rx(dBm)|Rx Att(db)|Tx(dBm)|Tx Att(db)|Comment" > "$OUT_FILE"

if [ ! -f "$IP_FILE" ]; then
    echo "Error: File $IP_FILE tidak ditemukan."
    exit 1
fi

echo "Output: $OUT_FILE"
echo "Referensi: $DEFAULT_FILE"
echo "Memulai pemrosesan..."

# Baca daftar IP
grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}" "$IP_FILE" | while read -r IP; do
    
    if check_alive "$IP"; then
        STATUS_MSG="\e[32mAlive\e[0m"
        IS_ALIVE=true
    else
        STATUS_MSG="\e[31mTime Out\e[0m"
        IS_ALIVE=false
    fi

    printf "IP: %-15s [%b]" "$IP" "$STATUS_MSG"

    if [ "$IS_ALIVE" = false ]; then
        echo -e "$(date +%d/%m/%Y)|$IP||||||||DEAD" >> "$OUT_FILE"
        echo ""
        continue
    fi

    RAW_NE=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_NE" 2>/dev/null)
    NENAME=$(clean_string "$RAW_NE")

    # Ambil index port
    ID_LIST=$(snmpwalk -v2c -c $COMMUNITY -t $TIMEOUT_SEC -r $RETRIES "$IP" "$OID_PORT" 2>/dev/null \
              | grep "NE\|NW\|OSC" | grep "STRING" \
              | cut -d'=' -f1 | awk -F'.' '{print $(NF-4)"."$(NF-3)"."$(NF-2)"."$(NF-1)"."$(NF)}')

    COUNT=0
    for k in $ID_LIST; do
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

        # --- LOGIKA CHECKING & COMMENT ---
        COMMENT=""
        if [[ -n "$RXATT" && -n "$PORTNAME" ]]; then
            
            # 1. Cek Kenaikan terhadap nilai Default
            DEFAULT_RXATT=$(get_default_rxatt "$IP" "$PORTNAME")
            if [[ -n "$DEFAULT_RXATT" ]]; then
                DIFF=$(echo "$RXATT - $DEFAULT_RXATT" | bc 2>/dev/null)
                # Gunakan bc untuk perbandingan floating point
                IS_HIGHER=$(echo "$DIFF > $THRESHOLD_DIFF" | bc 2>/dev/null)
                
                if [[ "$IS_HIGHER" -eq 1 ]]; then
                    COMMENT="RXATT NAIK $DIFF dB"
                fi
            fi

            # 2. Cek Ambang Batas Maksimum (32 dB)
            IS_EXCEED=$(echo "$RXATT > $THRESHOLD_MAX" | bc 2>/dev/null)
            if [[ "$IS_EXCEED" -eq 1 ]]; then
                if [[ -n "$COMMENT" ]]; then
                    COMMENT="$COMMENT, "
                fi
                COMMENT="${COMMENT}RXATT > ${THRESHOLD_MAX}dB ($RXATT)"
                
                # Tampilkan pesan Critical di terminal
                printf "\e[31m[CRITICAL]\e[0m IP: $IP Port: $PORTNAME RXATT kritis: $RXATT dB"
            elif [[ -n "$COMMENT" ]]; then
                # Tampilkan pesan Warning jika hanya kenaikan selisih
                printf "\e[33m[WARNING]\e[0m IP: $IP Port: $PORTNAME RXATT naik $DIFF dB"
            fi
        fi

        # Tulis ke file hasil
        if [[ -n "$PORTNAME" || -n "$RXLEV" || -n "$TXLEV" ]]; then
            CURRENT_DATE=$(date +%d/%m/%Y)
            echo "$CURRENT_DATE|$IP|$NENAME|$PORTNAME|$ALIASNAME|$RXLEV|$RXATT|$TXLEV|$TXATT|$COMMENT" >> "$OUT_FILE"
            ((COUNT++))
        fi
        
    done

    echo -e " -> \e[33m$COUNT ports processed\e[0m"

done

echo -e "Selesai. File hasil: $OUT_FILE"
