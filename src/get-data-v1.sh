#!/bin/sh

#daftar variable
OID_NAME=SNMPv2-SMI::enterprises.2544.1.11.2.2.1.1.0
OID_ALIAS=SNMPv2-SMI::enterprises.2544.1.11.2.4.3.1.1.1
OID_LINK=SNMPv2-SMI::enterprises.2544.1.11.2.4.3.41.1.5
OID_RX=SNMPv2-SMI::enterprises.2544.1.11.2.4.3.5.1.3
OID_TX=SNMPv2-SMI::enterprises.2544.1.11.2.4.3.5.1.4
TMP_FILE=/tmp/outmp
IP_ADVA=/root/APP/data_ip.txt
OUT_FILE=/root/APP/outdata.csv
IP=`cat $IP_ADVA`
rm -rf $OUT_FILE
echo "IP:NE:PORT:ALIAS:Rx (dBm):Tx (dBm)" >$OUT_FILE
for i in $IP
do
ALIVE=`ping -c 1 -w 1 $i &>/dev/null && echo Alive |grep Alive`
if  [ "$ALIVE" != "Alive" ] ; then
printf "Ambil data dari IP \e[33m$i\e[0m : "
echo -e "\e[31mTime Out\e[0m"
echo "$i:RTO:null:null:null:null" >> $OUT_FILE
else
printf "Ambil data dari IP \e[33m$i\e[0m : "
snmpwalk -v2c -c public $i $OID_LINK > $TMP_FILE
NEN=`snmpwalk -v2c -c public $i $OID_NAME |awk '{print $4}'|cut -d'"' -f2`
#snmpwalk -v2c -c public 172.29.162.10 $OID_LINK > $TMP_FILE
#NL=`grep 'STRING' $TMP_FILE|awk '{print $4}'|cut -d'"' -f2`
NLID=`sed 's/\.*\./&\n/g' $TMP_FILE |grep 'STRING'|awk '{print $1}'`
for j in $NLID 
do
#echo "$OID_RX.$j" 
#echo "$NLID" >>test
NL=`snmpwalk -v2c -c public $i $OID_LINK.$j |awk '{print $4}'|cut -d'"' -f2`
#AL=`snmpwalk -v2c -c public $i $OID_ALIAS.$j |awk '{print $4}'|cut -d'"' -f2`
AL=`snmpwalk -v2c -c public $i $OID_ALIAS.$j |awk '{$1=$2=$3="";print $0}'|cut -d'"' -f2`
RX=`snmpwalk -v2c -c public $i $OID_RX.$j |awk '{print $4}'|cut -d'"' -f2|sed 's/\B[0-9]\{1\}\>/,&/'`
TX=`snmpwalk -v2c -c public $i $OID_TX.$j |awk '{print $4}'|cut -d'"' -f2|sed 's/\B[0-9]\{1\}\>/,&/'`
echo "$i:$NEN:$NL:$AL:$RX:$TX" >> $OUT_FILE
done
echo -e "\e[32mDone\e[0m"
fi
done

rm -rf $TMP_FILE
