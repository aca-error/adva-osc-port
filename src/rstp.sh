#!/bin/bash

# Daftar OID
OID_NE="SNMPv2-SMI::enterprises.2544.1.11.2.2.1.1.0"
OID_RSTP="SNMPv2-SMI::enterprises.2544.1.11.7.3.3.7.1.90"
TMPDIR="/root/app/tmp"
rm -rf "$TMPDIR"
mkdir -p "$TMPDIR"
TMP_FILE="$TMPDIR/otmp"
IP_ADVA="/root/app/ip.profile"
OUT_FILE="/root/app/RSTP_$(date +%Y%m%d).csv"
FTMP="$TMPDIR/ftmp"
IP_LIST=$(grep -v "#" "$IP_ADVA")
TO=60
RET=3

# Header Output
echo -e "DATE|IP|NE|SLOT|RSTP" > "$OUT_FILE"

# Looping setiap IP
for IP in $IP_LIST; do
    if ping -c 1 -w 1 -q "$IP" &>/dev/null; then
        printf "Ambil data dari IP \e[33m%s\e[0m : " "$IP"
        NENAME=$(snmpwalk -v2c -c public -t $TO -r $RET "$IP" "$OID_NE" | awk '{print $4}' | tr -d '"')
        RSTP_OUTPUT=$(snmpwalk -v2c -c public -t $TO -r $RET "$IP" "$OID_RSTP")

        if [[ -z "$RSTP_OUTPUT" ]]; then
            echo -e "\e[31mNo Data\e[0m"
            echo -e "$(date +%d/%m/%Y)|$IP|$NENAME|#N/A|#N/A" >> "$OUT_FILE"
        else
            j=1
            > "$FTMP"
            while read -r line; do
                OSCSLOT=$(echo "$line" | awk -F "." '{print $11 "-" $12}')
                RSTPSTAT=$(echo "$line" | awk -F ": " '{print $2}')

                case "$RSTPSTAT" in
                    1) STATUS="ENABLE" ;;
                    2) STATUS="DISABLE" ;;
                    *) STATUS="UNKNOWN" ;;
                esac

                echo -e "IPX[$j]=\"$IP\"\nNEX[$j]=\"$NENAME\"\nSLOTX[$j]=\"$OSCSLOT\"\nRSTPX[$j]=\"$STATUS\"" >> "$FTMP"
                j=$((j + 1))
            done <<< "$RSTP_OUTPUT"

            unset IPX NEX SLOTX RSTPX
            . "$FTMP"

            for ((m = 1; m < j; m++)); do
                echo -e "$(date +%d/%m/%Y)|${IPX[$m]}|${NEX[$m]}|${SLOTX[$m]}|${RSTPX[$m]}" >> "$OUT_FILE"
            done
            echo -e "\e[32mDone\e[0m"
        fi
    else
        printf "Ambil data dari IP \e[33m%s\e[0m : " "$IP"
        echo -e "\e[31mTime Out\e[0m"
        echo -e "$(date +%d/%m/%Y)|$IP|#N/A|#N/A|#N/A" >> "$OUT_FILE"
    fi
done

rm -rf "$TMPDIR"
exit

