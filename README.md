ProxySQL / PXC lab
==================

# Setup

```
docker-compose up
./setup.bash
mysql -h 127.0.0.1 -P6033 -u user -ppass
```

To connect to proxysqladmin:

```
mysql -h 127.0.0.1 -P6032 -uadmin -padmin
```

You can also `source ./setup.bash` to access the following convenience functions:

- `lab_pxc <query> [nodeID] [database]`: execute `query` on `nodeID` (default: 0) and `database` (default: none)
- `lab_proxyadmin`: execute command on proxysql admin
- `lab_proxysql <query> [database]`: execute `query` on  `database` (default: none) via proxysql.


# R/W splitting in action

To check if R/W splitting is occuring, activage general_log on all nodes:

```
source ./setup.bash
for i in 0 1 2; do lab_pxc "SET GLOBAL general_log='ON';" $i; done
```

Then, in another terminal, insert stuff:

```
source ./setup.bash
lab_proxysql "CREATE DATABASE foo; USE foo; CREATE TABLE bar (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(200));"
while true; do lab_proxysql "INSERT INTO bar VALUES ('', '$RANDOM');" foo; done
```

Now, check the general log to see where writes happen:

```
for i in 0 1 2; do echo -e  "\nNODE $i\n"; docker exec -ti proxysql_node${i}_1 tail -5 /var/lib/mysql/node${i}.log; done

NODE 0

           19 Query INSERT INTO bar VALUES ('', '27532')
           19 Query INSERT INTO bar VALUES ('', '32332')
           19 Query INSERT INTO bar VALUES ('', '815')
           19 Query INSERT INTO bar VALUES ('', '19951')
           19 Query INSERT INTO bar VALUES ('', '22094')

NODE 1

            4 Query BEGIN
            3 Query BEGIN
            3 Query BEGIN
            1 Query BEGIN
            1 Query BEGIN

NODE 2

            4 Query BEGIN
            5 Query BEGIN
            5 Query BEGIN
            3 Query BEGIN
            3 Query BEGIN
```

Don't forget to kill your insert loop, and deactivate general log:

```
for i in 0 1 2; do lab_pxc "SET GLOBAL general_log='OFF';" $i; done
```