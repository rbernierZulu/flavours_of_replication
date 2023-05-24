#!/bin/bash

set -e

echo "==== set postgres password, generate keys ===="
lxc exec pg1 -- su -l postgres <<_eof_
    rm -rf /var/lib/postgresql/.ssh/*

    ssh-keygen -b 2048 -t rsa -f /var/lib/postgresql/.ssh/id_rsa -q -N ""

    export SSHPASS=postgres
    sshpass -e ssh-copy-id -o StrictHostKeyChecking=no postgres@pg2
    sshpass -e ssh-copy-id -o StrictHostKeyChecking=no postgres@pg3
_eof_

echo "==== create WAL directory on pg2 ===="
lxc exec pg2 bash<<_eof_
    su - postgres
    mkdir -p /var/lib/postgresql/WAL
_eof_

echo "==== update runtime settings on pg1 ===="
lxc exec pg1 bash<<_eof_

echo "
archive_mode = 'on'
archive_command = 'scp %p pg2:WAL'
wal_keep_size = 100
wal_log_hints = 'on'
" >> /var/lib/postgresql/14/main/postgresql.auto.conf

systemctl restart postgresql@14-main
_eof_

echo "==== generating wals ... pg1 ===="
lxc exec pg1 -- su -l postgres -c psql <<_eof_
    alter role postgres password 'postgres';

    drop database if exists db01;
    create database db01;
   \c db01
    select *, 'hello world'::text as comments
        into table t1
        from (select generate_series from generate_series(1,1e6))t;

    checkpoint;
    select pg_walfile_name(pg_switch_wal());
_eof_

echo "==== validating wals ... pg2 ===="
lxc exec pg2 -- su -l postgres <<_eof_
    ls -l WAL
_eof_
