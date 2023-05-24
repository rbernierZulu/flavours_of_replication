#!/bin/bash

set -e

echo "==== clean PGDATA ===="
lxc exec pg2 bash <<_eof_
    systemctl stop postgresql@14-main
    rm -rf /var/lib/postgresql/14/main
_eof_

echo "==== perform basebackup ===="
lxc exec pg2 -- su -l postgres <<_eof_

/usr/lib/postgresql/14/bin/pg_basebackup \
    -d  'host=pg1 user=postgres password=postgres port=5432' \
    --wal-method=stream \
    -c fast \
    -l basebackup \
    -D /var/lib/postgresql/14/main \
    -P -v

echo "
hot_standby = 'on'
recovery_target_timeline = 'latest'

restore_command = 'cp /var/lib/postgresql/WAL/%f \"%p\"'
archive_cleanup_command = '/usr/lib/postgresql/14/bin/pg_archivecleanup /var/lib/postgresql/WAL %r'
" >> /var/lib/postgresql/14/main/postgresql.auto.conf

touch /var/lib/postgresql/14/main/standby.signal

_eof_


lxc exec pg2 bash <<_eof_
    systemctl start postgresql@14-main
    netstat -tlnp
_eof_

lxc exec pg2 bash <<_eof_
    psql 'host=pg1 dbname=db01 user=postgres password=postgres'<<_eof1_
        drop table if exists t2;
        select * into table t2 from generate_series(1,1e6);
        checkpoint;
        select pg_switch_wal();
_eof1_

echo "sleep 15 seconds ..."; sleep 15s

psql 'host=pg2 dbname=db01 user=postgres password=postgres' -c '\dt+'
_eof_
