#!/bin/bash
#Script to create and init Sugar oracle user

if [ "$SUGAR_DB_TYPE" != "oci8" ]; then
	echo "Non-oracle installation type - exiting"
	exit 0
fi

#wait for oracle $wait times by $slp seconds
wait=120
slp=5

#tablespace parameters
ts_name=sugardata
ts_sizeg=1

wait_for_oracle(){
 echo -n "Checking for Oracle server: $ORACLE_HOST"
 connection="system/oracle@//$ORACLE_HOST:$ORACLE_PORT/$ORACLE_SERVICE"
 db_ok=1
 n_att=1
 while [ $db_ok = 1 ];
  do
   echo -n "*"
   n_att=$((n_att+1))
 retval=`sqlplus -silent $connection <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT 'Alive' FROM dual;
EXIT;
EOF` || true
   if [ "$retval" = "Alive" ]; then
     db_ok=0
   fi
   sleep $slp
   if [ $n_att -gt $wait ]; then
     echo "FAIL"
     echo "WARNING: Cannot connect to Oracle after 20 attempts"
     echo "Raw sqlplus output is: $retval"
     break
   fi
  done
 echo "SUCESS!"
 echo "Oracle server is ready:  $ORACLE_HOST"
}


wait_for_oracle

echo "Running sqlplus to create database object for Sugar"
sqlplus -silent  /nolog  << EOF
connect system/oracle@${TNS_NAME}
create bigfile tablespace $ts_name datafile '/u01/app/oracle/oradata/$ORACLE_SERVICE/$ts_name.dbf' size ${ts_sizeg} G;
create user $DB_USER identified by $DB_PASS;
grant dba to $DB_USER;
alter user $DB_USER default tablespace $ts_name temporary tablespace temp;

create or replace trigger logon_trigger
after logon on database
begin
  /*USERNAME SHOULD BE IN UPPERCASE*/
  if ( user = '$DB_USER' ) then
    execute immediate 'ALTER SESSION SET CURSOR_SHARING=FORCE';
    execute immediate 'ALTER SESSION SET SESSION_CACHED_CURSORS=100';
  end if;
end; 
/

exit;
EOF

