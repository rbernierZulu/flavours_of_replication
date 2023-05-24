#!/bin/bash

set -e

lxc exec pg3 bash <<_eof_

systemctl stop postgresql@14-main
rm -rf /var/lib/postgresql/14/main

su - postgres<<_eof1_
    /usr/lib/postgresql/14/bin/pg_basebackup \
        -d 'host=pg2 user=postgres password=postgres port=5432' \
        --wal-method=stream \
        -c fast \
        -l basebackup \
        -D /var/lib/postgresql/14/main \
        -R -P -v \
        --create-slot \
        --slot=pg3

    touch /var/lib/postgresql/14/main/standby.signal
_eof1_

systemctl start postgresql@14-main

echo "sleeping 5 seconds ..." && sleep 5s

psql 'host=pg2 user=postgres password=postgres' <<_eof1_
    \echo === HOST PG2 ===
    select slot_name, slot_type, active, active_pid from pg_replication_slots;
_eof1_

psql 'host=pg1 user=postgres password=postgres' <<_eof1_
    \echo === HOST PG1 ===
    select slot_name, slot_type, active, active_pid from pg_replication_slots;
_eof1_

_eof_
