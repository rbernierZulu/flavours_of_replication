#!/bin/bash

set -e

lxc exec pg1 -- su -l postgres <<_eof_
psql <<_eof1_
    alter system set wal_level=logical;
    drop database if exists db01;
    create database db01;
   \c db01
    create schema a;
    create table a.t1(i serial primary key, comments text);
_eof1_
_eof_

echo "==== sleeping 5 seconds ..." && sleep 5s

lxc exec pg1 bash <<_eof_
    systemctl restart postgresql@14-main
_eof_

lxc exec pg2 bash <<_eof_
    systemctl restart postgresql@14-main
_eof_


lxc exec pg2 -- su -l postgres <<_eof_

psql <<_eof1_
    select pg_promote();

   \c 'host=pg1 dbname=db01 password=postgres'
    create publication provider1 for table a.t1;

   \c 'host=pg2 dbname=db01 password=postgres'
    create subscription mysub
        connection 'host=pg1 port=5432 user=postgres dbname=db01 password=postgres'
        publication provider1
               with (enabled = true);

   \c 'host=pg1 dbname=db01 password=postgres'
    select * from pg_stat_replication;
    select * from pg_get_replication_slots();
_eof1_
_eof_
