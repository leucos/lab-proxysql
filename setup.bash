#!/bin/bash

function lab_pxc() {
    cmd=${1}
    node=${2:-0}
    database=${3:-""}
    xip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' proxysql_node${node}_1)
    mysql -h ${xip} -P3306 "${database}" -e "${cmd}"
}


function lab_proxyadmin() {
    pip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' proxysql_proxysql_1)
    mysql -h ${pip} -P6032 -uadmin -padmin -e "$1" 2>/dev/null
}


function lab_proxysql() {
    cmd=${1}
    database=${2:-""}    
    pip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' proxysql_proxysql_1)
    mysql -h 127.0.0.1 -P6033 -uuser -ppass  "${database}" -e "$cmd"
}

# Not necessary since we skip grant tables
# pxc 0 "mysql" "GRANT ALL ON *.* TO 'proxyuser'@'%' IDENTIFIED BY 'toortoor'"

function lab_cleanup() {
  for table in scheduler mysql_query_rules mysql_users mysql_servers; do
    lab_proxyadmin "DELETE FROM ${table}"
  done
}

function lab_setup() {
    lab_cleanup

    for i in node0 node1 node2; do
        ip=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' proxysql_${i}_1)
        lab_proxyadmin "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (0, '$ip', 3306, 20);"
        lab_proxyadmin "INSERT INTO mysql_servers (hostgroup_id, hostname, port, max_replication_lag) VALUES (1, '$ip', 3306, 20);"
    done

    lab_proxyadmin "INSERT INTO mysql_users (username, password, active, default_hostgroup, max_connections) VALUES ('user', 'pass', 1, 0, 200);"

    lab_proxyadmin "INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, apply) VALUES (1, '.*@.*', 0, 1);"
    lab_proxyadmin "INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, apply) VALUES (1, '^SELECT.*', 1, 0);"
    lab_proxyadmin "INSERT INTO mysql_query_rules (active, match_pattern, destination_hostgroup, apply) VALUES (1, '^SELECT.*FOR UPDATE', 0, 1);"

    lab_proxyadmin "INSERT INTO scheduler (id, interval_ms, filename, arg1, arg2, arg3, arg4, arg5) VALUES (1, 1000, '/usr/local/bin/proxysql_galera_checker.sh', 0, 1, 1, 1, '/tmp/galera_checker.log');"
    lab_proxyadmin "SET mysql-query_retries_on_failure=10;"

    lab_proxyadmin "LOAD MYSQL USERS TO RUNTIME; SAVE MYSQL USERS TO DISK; LOAD MYSQL QUERY RULES TO RUNTIME; SAVE MYSQL QUERY RULES TO DISK; LOAD MYSQL SERVERS TO RUNTIME; SAVE MYSQL SERVERS TO DISK; LOAD SCHEDULER TO RUNTIME; SAVE SCHEDULER TO DISK; LOAD MYSQL VARIABLES TO RUNTIME; SAVE MYSQL VARIABLES TO DISK;"
}

if [[ $_ == $0 ]]; then
    lab_setup
fi
