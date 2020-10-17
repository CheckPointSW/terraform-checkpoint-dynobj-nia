#!/bin/bash
# v1.2 - HashiCorp Consul Integration
# This script is for Check Point Mgmt Station

# Check Point Mgmt Station credentials
vUSERNAME="consul-io"
vPASSWORD="test123"
# vUSERNAME="consul_user"
# vPASSWORD="test123"

. /etc/init.d/functions
. /opt/CPshared/5.0/tmp/.CPprofile.sh

vDATE=`date +%Y-%m-%d_%H:%M:%S`
vIGNORE_OBJECTS="AuxiliaryNet|CPDShield|DMZNet|InternalNet|LocalMachine"
vDIR_CONSUL=/usr/local/consul
vCURRENT=$vDIR_CONSUL/current
vPREVIOUS=$vDIR_CONSUL/previous
vCURRENT_hash=$vDIR_CONSUL/tmp/current_hash
vPREVIOUS_hash=$vDIR_CONSUL/tmp/previous_hash
vCONSUL_LOG=$vDIR_CONSUL/log/consul.log
vGW_SCRIPT=$vDIR_CONSUL/consul-gw.sh
vGW_IP=$vDIR_CONSUL/gateways
vGW_FILE_current=$vDIR_CONSUL/current
vGW_FILE_md5=$vDIR_CONSUL/tmp/gw_md5_cmd
vGW_FILE_setup_ignore=$vDIR_CONSUL/tmp/gw_setup_cmd_ignore
vGW_FILE_setup=/tmp/gw_setup_cmd
vID=$vDIR_CONSUL/tmp/sid.txt
vTMP_ADDR_OUT=$vDIR_CONSUL/tmp/tmp-addr-out
vTMP_ADDR_SORT=$vDIR_CONSUL/tmp/tmp-addr-sort
vTMP_OBJ=$vDIR_CONSUL/tmp/tmp_obj
vTMP_OBJ_FLAT=$vDIR_CONSUL/tmp/tmp_obj_flat

for file in "$vCURRENT" "$vPREVIOUS" "$vCURRENT_hash" "$vPREVIOUS_hash" "$vCONSUL_LOG" "$vGW_SCRIPT" "$vGW_IP" "$vGW_FILE_current" "$vGW_FILE_md5" "$vGW_FILE_setup_ignore" "$vGW_FILE_setup" "$vID" "$vTMP_ADDR_OUT" "$vTMP_ADDR_SORT" "$vTMP_OBJ" "$vTMP_OBJ_FLAT"
do 
    if [ ! -f "$file" ]; then
    touch $file
    fi
done


f_update_objects () {

echo > $vTMP_ADDR_SORT
echo > $vTMP_OBJ
echo > $vTMP_OBJ_FLAT

mgmt_cli login user $vUSERNAME password $vPASSWORD > $vID
mgmt_cli show dynamic-objects -s $vID details-level full limit 500 --format json > $vTMP_ADDR_OUT

loop=0
while [ $loop == 0 ]; do
vTO=$(cat $vTMP_ADDR_OUT | grep -w "to\"\ :" | awk -F ":" '{print $2}' | sed s/,//g | tail -1)
vTOTAL=$(cat $vTMP_ADDR_OUT | grep -w "total\"\ :" | awk -F ":" '{print $2}' | sed s/,//g | tail -1)
if [ $vTOTAL != 0 ];
  then
      mgmt_cli show dynamic-objects -s $vID details-level full limit 500 offset $vTO --format json >> $vTMP_ADDR_OUT
  else
      loop=1
fi
done

mgmt_cli logout -s $vID > /dev/null
}

f_update_parse () {

# Go through the json file and find objects and the tag names with IP addresses
for i in $(jq -r '.objects[] |.uid' $vTMP_ADDR_OUT); do 
   comments=$(jq -r --arg i "$i" '.objects[]|select (.uid ==$i)| .comments' $vTMP_ADDR_OUT) 
   objectname=$(jq -r --arg i "$i" '.objects[]|select (.uid ==$i)| .name' $vTMP_ADDR_OUT)
#  insert check for the right object here
   if [[ "$comments" == "consul" ]]; then
      for k in $(jq -r --arg i "$i" '.objects[]|select (.uid ==$i)| .tags[]' $vTMP_ADDR_OUT | jq -r '.name'); do
         ipaddress=$(echo $k |grep -E -o "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)")
#  if it is a valid IP address, write the files
      if [[ $ipaddress =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
         echo "$objectname,$ipaddress" >> $vTMP_ADDR_SORT
      fi
   done
   fi
done

vSVC=`cat $vTMP_ADDR_SORT | awk -F "," '{print $1}' | sort -u`

for i in $vSVC; do
    echo -n `cat $vTMP_ADDR_SORT| grep -w "$i" | awk -F "," '{print $2","}'` | sed s/\ //g | sed 's/,*\r*$//' > $vTMP_OBJ
    echo $i,`cat $vTMP_OBJ` >> $vTMP_OBJ_FLAT
done

cat $vTMP_OBJ_FLAT | grep -v -e '^$' > $vCURRENT
rm $vID $vTMP_ADDR_OUT $vTMP_OBJ_FLAT $vTMP_ADDR_SORT $vTMP_OBJ

}

f_gw_check() {
echo "md5sum $vGW_FILE_current" > $vDIR_CONSUL/tmp/gw_md5_cmd
for i in `cat $vGW_IP | awk -F "," '{print $1}'`
    do
    vREMOTE_hash=`$CPDIR/bin/cprid_util -server $i putfile -local_file $vDIR_CONSUL/tmp/gw_md5_cmd -remote_file $vGW_FILE_md5; $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd /bin/bash -f $vGW_FILE_md5 | awk '{print $1}'`
    if [ "$vCURRENT_check" == "$vREMOTE_hash" ] ;
        then
            echo "$vDATE No changes for $i" >> $vCONSUL_LOG
        else
            echo "$vDATE Updating $i" >> $vCONSUL_LOG
            $CPDIR/bin/cprid_util -server $i putfile -local_file $vCURRENT -remote_file $vGW_FILE_current
            $CPDIR/bin/cprid_util -server $i rexec -rcmd /bin/bash -f $vGW_SCRIPT
            echo "$vDATE Update complete for $i" >> $vCONSUL_LOG
    fi
done
rm $vDIR_CONSUL/tmp/gw_md5_cmd
}

f_gw_update() {
for i in `cat $vGW_IP | awk -F "," '{print $1}'`
    do
        echo "$vDATE Updating $i" >> $vCONSUL_LOG
        $CPDIR/bin/cprid_util -server $i putfile -local_file $vCURRENT -remote_file $vGW_FILE_current
        $CPDIR/bin/cprid_util -server $i rexec -rcmd /bin/bash -f $vGW_SCRIPT;
        echo "$vDATE Update complete for $i" >> $vCONSUL_LOG
    done
}

f_start(){
# Start
/usr/bin/md5sum $vCURRENT | awk '{print $1}'> $vCURRENT_hash
/usr/bin/md5sum $vPREVIOUS | awk '{print $1}' > $vPREVIOUS_hash

vCURRENT_check=`cat $vCURRENT_hash`
vPREVIOUS_check=`cat $vPREVIOUS_hash`

if [ "$vCURRENT_check" == "$vPREVIOUS_check" ] ;
    then
        echo "$vDATE No changes from Consul" >> $vCONSUL_LOG
        f_gw_check
    else
        echo "$vDATE Changes detected" >> $vCONSUL_LOG
        f_gw_update
        cp $vCURRENT $vPREVIOUS
fi

}

f_check_gw() {
for i in `cat $vGW_IP | grep -v init`
    do
    echo "mkdir -p /usr/local/consul /usr/local/consul/tmp /usr/local/consul/log && touch /usr/local/consul/current" > $vDIR_CONSUL/tmp/gw_setup_cmd
    echo "dynamic_objects -l | grep name | sed s/\object\ name\ \:\ //g > /usr/local/consul/svc_ignore" > $vDIR_CONSUL/tmp/gw_setup_cmd_ignore
    $CPDIR/bin/cprid_util -server $i putfile -local_file $vDIR_CONSUL/tmp/gw_setup_cmd -remote_file $vGW_FILE_setup; $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd /bin/bash -f $vGW_FILE_setup | grep [0-9]
    $CPDIR/bin/cprid_util -server $i putfile -local_file $vDIR_CONSUL/tmp/gw_setup_cmd_ignore -remote_file $vGW_FILE_setup_ignore; $CPDIR/bin/cprid_util -server $i -verbose rexec -rcmd /bin/bash -f $vGW_FILE_setup_ignore
    $CPDIR/bin/cprid_util -server $i putfile -local_file $vGW_SCRIPT -remote_file $vGW_SCRIPT
    sed -i 's/'$i'/'$i',init/g' $vGW_IP
    echo "$vDATE Created Consul directories and files on gateway $i" >> $vCONSUL_LOG
    rm $vDIR_CONSUL/tmp/gw_setup_cmd
    done
    rm $vDIR_CONSUL/tmp/gw_setup_cmd_ignore
}

# Start
f_check_gw
f_update_objects
f_update_parse
f_start