#!/bin/bash

set -e


lxc exec pg3 bash <<_eof_

echo "==== basebackup on pg3 ===="

systemctl stop postgresql@14-main
rm -rf /var/lib/postgresql/14/main

su - postgres<<_eof1_
    /usr/lib/postgresql/14/bin/pg_basebackup \
        -d 'host=pg1 user=postgres password=postgres port=5432' \
        --wal-method=stream \
        -c fast \
        -l basebackup \
        -D /var/lib/postgresql/14/main \
        -R -P -v \
        --create-slot \
        --slot=pg3

    echo "cluster_name = 'pg3'" >> /var/lib/postgresql/14/main/postgresql.auto.conf
    touch /var/lib/postgresql/14/main/standby.signal
_eof1_

systemctl start postgresql@14-main

_eof_


lxc exec pg2 bash <<_eof_

echo "==== basebackup on pg2 ===="

systemctl stop postgresql@14-main
rm -rf /var/lib/postgresql/14/main

su - postgres<<_eof1_
    /usr/lib/postgresql/14/bin/pg_basebackup \
        -d 'host=pg1 user=postgres password=postgres port=5432' \
        --wal-method=stream \
        -c fast \
        -l basebackup \
        -D /var/lib/postgresql/14/main \
        -R -P -v \
        --slot=pg2

    echo "cluster_name = 'pg2'" >> /var/lib/postgresql/14/main/postgresql.auto.conf
    touch /var/lib/postgresql/14/main/standby.signal
_eof1_

systemctl start postgresql@14-main

_eof_

echo "sleeping 5 seconds ..." && sleep 5s

echo "==== UPDATE replication type on pg1 ===="
lxc exec pg1 -- su -l postgres <<_eof_

psql <<_eof1_
    show synchronous_commit;
    alter system set synchronous_standby_names='pg2,pg3';
    alter system set primary_slot_name='pg1';
    select pg_reload_conf();
    select application_name,state,sync_state from pg_stat_replication order by 1;
_eof1_
_eof_
