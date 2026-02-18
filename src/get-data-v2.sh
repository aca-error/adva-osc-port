#!/bin/bash

#daftar variable
OID_NE=SNMPv2-SMI::enterprises.2544.1.11.2.2.1.1.0
OID_PORT=SNMPv2-SMI::enterprises.2544.1.11.7.2.3.1.6
OID_ALIAS=SNMPv2-SMI::enterprises.2544.1.11.7.3.5.3.1.4
OID_RX=SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.2
OID_RXATT=SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.11
OID_TX=SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.1
OID_TXATT=SNMPv2-SMI::enterprises.2544.1.11.7.7.2.3.1.10
OID_CHILD=SNMPv2-SMI::enterprises.2544.1.11.2.4.1.12.1.2
TMPDIR=/root/app/tmp
rm -rf $TMPDIR
mkdir $TMPDIR
TMP_FILE=$TMPDIR/otmp
IP_ADVA=/root/app/ip.profile
OUT_FILE=/root/app/$(date +%Y%m%d).csv
FTMP=$TMPDIR/ftmp
IP=$(grep -v "#" $IP_ADVA)
TO=60
RET=3
unset IPX
unset NEX
unset PORTX
unset ALIASX
unset RXX
unset RXATTX
unset TXX
unset TXATTX
echo -e "DATE|IP|NE|PORT|ALIAS|Rx(dBm)|Rx Att(db)|Tx(dBm)|Tx Att(db)" >$OUT_FILE
for i in $IP; do
    ALIVE=$(ping -c 1 -w 1 $i &>/dev/null && echo Alive | grep Alive)
    if [ "$ALIVE" != "Alive" ]; then
        printf "Ambil data dari IP \e[33m$i\e[0m : "
        echo -e "\e[31mTime Out\e[0m"
        echo -e "$(date +%d/%m/%Y)|$i|#N/A|#N/A|#N/A|#N/A|#N/A|#N/A|#N/A" >>$OUT_FILE
    else
        printf "Ambil data dari IP \e[33m$i\e[0m : "
        NENAME=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_NE | awk '{print $4}' | cut -d'"' -f2)
        ID_GET=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_PORT | grep "NE\|NW\|OSC" | grep "STRING" | awk -F "." '{print $10 "." $11 "." $12 "." $13 "." $14}' | cut -d ' ' -f1)
        j=1
        for k in $ID_GET; do
            PORTNAME=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_PORT | grep $k | awk '{print $4}' | cut -d'"' -f2)
            ALIASNAME=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_ALIAS | grep "STRING" | grep $k | awk -F '"' '{print $2}')
            RXLEV=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_RX | grep "INTEGER" | grep $k | awk '{print $4}' | cut -d'"' -f2 | sed 's/\B[0-9]\{1\}\>/.&/')
            RXATT=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_RXATT | grep "INTEGER" | grep $k | awk '{print $4}' | cut -d'"' -f2 | sed 's/\B[0-9]\{1\}\>/.&/')
            TXLEV=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_TX | grep "INTEGER" | grep $k | awk '{print $4}' | cut -d'"' -f2 | sed 's/\B[0-9]\{1\}\>/.&/')
            TXATT=$(snmpwalk -v2c -c public -t $TO -r $RET $i $OID_TXATT | grep "INTEGER" | grep $k | awk '{print $4}' | cut -d'"' -f2 | sed 's/\B[0-9]\{1\}\>/.&/')
            TX_LENGTH=$(echo $TXLEV | awk '{print length}')
            if [ $TX_LENGTH != 1 ]; then
                echo -e "IPX[$j]=\"$i\"\nNEX[$j]=\"$NENAME\"\nPORTX[$j]=\"$PORTNAME\"\nALIASX[$j]=\"$ALIASNAME\"\nRXX[$j]=\"$RXLEV\"\nRXATTX[$j]=\"$RXATT\"\nTXX[$j]=\"$TXLEV\"\nTXATTX[$j]=\"$TXATT\"" >>$FTMP
            else
                echo -e "IPX[$j]=\"$i\"\nNEX[$j]=\"$NENAME\"\nPORTX[$j]=\"$PORTNAME\"\nALIASX[$j]=\"$ALIASNAME\"\nRXX[$j]=\"$RXLEV\"\nRXATTX[$j]=\"$RXATT\"\nTXX[$j]=\"0.$TXLEV\"\nTXATTX[$j]=\"$TXATT\"" >>$FTMP
            fi
            j=$(expr $j + 1)
        done
        unset IPX
        unset NEX
        unset PORTX
        unset ALIASX
        unset RXX
        unset RXATTX
        unset TXX
        unset TXATTX
        . $FTMP
        m=1
        n=$(echo ${#PORTX[@]})
        while [ $m -le $n ]; do
            echo -e "$(date +%d/%m/%Y)|${IPX[$m]}|${NEX[$m]}|${PORTX[$m]}|${ALIASX[$m]}|${RXX[$m]}|${RXATTX[$m]}|${TXX[$m]}|${TXATTX[$m]}" >>$OUT_FILE
            m=$(expr $m + 1)
        done
        echo -e "\e[32mDone\e[0m"
        >$FTMP
    fi
done
rm -rf $TMPDIR
exit

