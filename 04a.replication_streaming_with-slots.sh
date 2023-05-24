#!/bin/bash

set -e

lxc exec pg2 bash <<_eof_

psql 'host=pg1 user=postgres password=postgres' <<_eof1_ 2>/dev/null
    select * from pg_create_physical_replication_slot('pg2');
   \c 'host=pg2 user=postgres password=postgres'
    alter system set primary_slot_name = 'pg2';
_eof1_

systemctl reload postgresql@14-main

psql 'host=pg1 user=postgres password=postgres' <<_eof1_
    select slot_name, slot_type, active, active_pid from pg_replication_slots;
_eof1_

_eof_
