#!/bin/bash

set -e

lxc exec pg1 -- su -l postgres <<_eof_
psql <<_eof1_
    drop role if exists replicant;
    create role replicant with login replication password 'mypassword';
    alter system set wal_level = 'replica';
_eof1_
_eof_

lxc exec pg1 bash<<<'systemctl restart postgresql@14-main'

lxc exec pg2 -- su -l postgres <<_eof_
psql<<_eof1_
    alter system set primary_conninfo = 'host=pg1 user=replicant password=mypassword';
_eof1_
_eof_

lxc exec pg2 bash<<<'systemctl restart postgresql@14-main'

lxc exec pg1 -- su -l postgres <<_eof_ | less -S
psql<<_eof1_
    select * from pg_stat_replication;
_eof1_
_eof_
