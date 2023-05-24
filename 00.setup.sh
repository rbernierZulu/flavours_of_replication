#!/bin/bash


set +e
lxc rm --force template-percona-live-replication pg1 pg2 pg3 2>/dev/null

set -e
lxc cp template-pg10-11-12-13-14-pgbouncer template-percona-live-replication

sleep 1s && \
lxc start template-percona-live-replication

lxc exec template-percona-live-replication bash<<_eof_

pg_dropcluster --stop 10 main
pg_dropcluster --stop 11 main
pg_dropcluster --stop 12 main
pg_dropcluster --stop 13 main
systemctl stop pgbouncer
systemctl disable pgbouncer

echo "
listen_addresses = '*'
logging_collector = 'on'
" >> /var/lib/postgresql/14/main/postgresql.auto.conf
systemctl restart postgresql@14-main

echo "postgres:postgres" | chpasswd
apt install -y sshpass

_eof_

lxc cp template-percona-live-replication pg1
lxc cp template-percona-live-replication pg2
lxc cp template-percona-live-replication pg3

lxc network attach lxdbr0 pg1 eth0 eth0
lxc network attach lxdbr0 pg2 eth0 eth0
lxc network attach lxdbr0 pg3 eth0 eth0

lxc config device set pg1 eth0 ipv4.address 10.231.38.11
lxc config device set pg2 eth0 ipv4.address 10.231.38.12
lxc config device set pg3 eth0 ipv4.address 10.231.38.13

lxc start pg1 pg2 pg3 && sleep 3s
lxc ls -c ns4 pg
