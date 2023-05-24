#!/bin/bash

set -e

lxc exec pg2 bash <<_eof_

systemctl stop postgresql@14-main
rm -rf /var/lib/postgresql/14/main

su -l postgres <<_eof1_
/usr/bin/pg_basebackup -d 'host=pg1 user=postgres password=postgres port=5432' \
                       --wal-method=stream \
                       -l basebackup \
                       -D /var/lib/postgresql/14/main \
                       -R -P -v \
                       --slot=pg2

touch /var/lib/postgresql/14/main/standby.signal
_eof1_

systemctl start postgresql@14-main

echo "sleeping 5 seconds ..." && sleep 5s

psql 'host=pg1 user=postgres password=postgres' <<_eof1_
    select slot_name, slot_type, active, active_pid from pg_replication_slots;
_eof1_

_eof_

