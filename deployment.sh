#!/usr/bin/env bash

echo "### Updating base system"
aptitude update
aptitude full-upgrade

echo "### Installing Apache, PHP, git and generic PHP modules"
aptitude install apache2 libapache2-mod-php5 git php5-dev php5-gd php-pear php5-mysql php5-pgsql php5-sqlite php5-interbase php5-sybase php5-odbc libmdbodbc unzip make libaio1 bc screen htop

echo "### Configuring Apache and PHP"
rm /var/www/index.html
mkdir /var/www/test
chmod 777 /var/www/test
a2enmod auth_basic auth_digest
sed -i 's/AllowOverride None/AllowOverride AuthConfig/' /etc/apache2/sites-enabled/*
sed -i 's/magic_quotes_gpc = On/magic_quotes_gpc = Off/g' /etc/php5/*/php.ini
sed -i 's/extension=suhosin.so/;extension=suhosin.so/g' /etc/php5/conf.d/suhosin.ini
update-rc.d apache2 defaults

echo "### Restarting Apache web server"
service apache2 restart

echo "### Donwloading sqlmap test environment to /var/www"
cd /var/www
git clone https://github.com/sqlmapproject/testenv.git sqlmap

echo "### Installing MySQL database management system (clients, server, libraries)"
echo "### NOTE: when asked for a password, type 'testpass'"
aptitude install mysql-client mysql-server libmysqlclient-dev libmysqld-dev 
update-rc.d mysql defaults

echo "### Initializing MySQL test database and table"
echo "### NOTE: when asked for a password, type 'testpass'"
mysql -u root -p mysql < /var/www/sqlmap/schema/mysql.sql 

echo "### Installing PostgreSQL database management system (clients, server, libraries)"
aptitude install postgresql-client postgresql postgresql-server-dev-all libpq-dev 
update-rc.d postgresql defaults

echo "### Initializing PostgreSQL test database and table"
echo "### NOTE: when asked for a password, type 'testpass'"
echo "Now type: ALTER USER postgres WITH PASSWORD 'testpass'; - hit RETURN, type \q; - hit RETURN"
su postgres -c psql
passwd -d postgres
su postgres -c passwd
psql -U postgres -h 127.0.0.1 -c "CREATE DATABASE testdb;"
psql -U postgres -h 127.0.0.1 -d testdb -f /var/www/sqlmap/schema/pgsql.sql

echo "### Initializing Microsoft Access ODBC driver"
cat << EOF > /etc/odbc.ini
[testdb]
Description = Microsoft Access Database of testdb
Driver      = MDBToolsODBC
Database    = /var/www/sqlmap/dbs/access/testdb.mdb
Servername  = localhost
UserName    =
Password    =
port        = 4747
EOF

cat << EOF > /etc/odbcinst.ini
[MDBToolsODBC]
Description = MDB Tools ODBC drivers
Driver      = /usr/lib/libmdbodbc.so.0
Setup       =
FileUsage   = 1
CPTimeout   =
CPReuse     =
UsageCount  = 1
EOF

echo "### Installing Firebird database management system (clients, server, libraries)"
echo "### NOTE: when asked for a password, type 'testpass'"
aptitude install firebird2.5-super firebird2.5-dev
dpkg-reconfigure firebird2.5-super
update-rc.d firebird2.5-super defaults

echo "### Initializing Firebird test database"
echo "modify SYSDBA -pw testpass" | gsec -user SYSDBA -password masterkey
chmod 666 /var/www/sqlmap/dbs/firebird/testdb.fdb

echo "### Installing Oracle database management system (clients, server)"
cd /tmp
wget https://oss.oracle.com/debian/dists/unstable/non-free/binary-i386/oracle-xe_10.2.0.1-1.1_i386.deb
wget https://oss.oracle.com/debian/dists/unstable/non-free/binary-i386/oracle-xe-client_10.2.0.1-1.2_i386.deb
dpkg -i oracle-xe_10.2.0.1-1.1_i386.deb
dpkg -i oracle-xe-client_10.2.0.1-1.2_i386.deb
echo "### NOTE: when asked for a password, type 'testpass'"
/etc/init.d/oracle-xe configure

echo "### Download the Oracle Basic and SDK Instant Client packages from the OTN Instant Client page, http://www.oracle.com/technetwork/database/features/instant-client/ (e.g. instantclient-basic-linux-11.2.0.3.0.zip and instantclient-sdk-linux-11.2.0.3.0.zip), open a separate shell and unzip them in /opt directory"
echo "### Hit ENTER when you have done it"
read enter
cd /opt/instantclient_*
ln -s libclntsh.so.11.1 libclntsh.so

echo "### Configuring PHP for Oracle"
echo "### NOTE: when asked for a path, provide instantclient,/opt/instantclient_<VERSION>"
pecl install oci8
echo "extension=oci8.so" > /etc/php5/conf.d/oracle.ini
sed -i 's/\;oci8.privileged_connect = Off/oci8.privileged_connect = On/g' /etc/php5/*/php.ini

echo "### Patching /etc/profile with Oracle related variables"
cat << EOF >> /etc/profile

# Oracle
export ORACLE_HOME=/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib
export ORACLE_SID=XE

# IBM DB2
export IBM_DB_HOME=/opt/ibm/db2/V9.5/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$IBM_DB_HOME/lib32

# PATH
export PATH=\$PATH:/usr/lib/oracle/xe/app/oracle/product/10.2.0/server/bin/:/opt/ibm/db2/V9.5/bin/
EOF

source /etc/profile

echo "### Initializing Oracle test database and table"
sqlplus SYS/testpass@//127.0.0.1:1521/XE AS SYSDBA << EOF
@/var/www/sqlmap/schema/oracle.sql;
ALTER system SET processes=300 scope=spfile;
ALTER system SET sessions=300 scope=spfile;
EOF
service oracle-xe restart

echo "### Initializing system to allow installation of IBM DB2"
cat << EOF >> /etc/sysctl.conf

# Setting for IBM DB2
fs.aio-max-nr = 1048576
fs.file-max = 6815744
kernel.shmall = 2097152
kernel.shmmax = 536870912
kernel.shmmni = 4096
kernel.sem = 250 32000 100 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048586
EOF
sysctl -p
aptitude install alien autoconf2.13 binutils build-essential cpp-4.4 debhelper g++-4.4 gawk gcc-4.4 gcc-4.4-base gettext html2text ia32-libs ia32-libs-dev intltool-debian ksh lesstif2 libaio-dev libaio1 libbeecrypt7 libc6 libc6-dev libc6-dev-i386 libdb4.8 libelf-dev libelf1 libltdl-dev libltdl7 libmotif4 libodbcinstq1c2 libqt4-core libqt4-gui libsqlite3-0 libstdc++5 libstdc++6 libstdc++6-4.4-dev lsb lsb-core lsb-cxx lsb-desktop lsb-graphics lsb-qt4 make odbcinst openjdk-6-jdk pax po-debconf rpm rpm-common sysstat tzdata-java unixodbc unixodbc-dev unzip xorg iceweasel

echo "### Download IBM DB2 trial from IBM software portal, http://www14.software.ibm.com/webapp/download/preconfig.jsp?id=2007-10-30+16%3A22%3A45.136755R&S_TACT=&S_CMP= and install it in a separate shell"
echo "### An how-to can be found on http://edin.no-ip.com/blog/hswong3i/ibm-db2-v9-7-apache-2-2-php5-3-debian-squeeze-howto"
echo "### Hit ENTER when you have done it"
read enter

echo "### Configuring PHP for IBM DB2"
echo "### NOTE: when asked for the DB2 installation directory, provide <TODO>"
pecl install ibm_db2
echo "extension=ibm_db2.so" > /etc/php5/conf.d/db2.ini

echo "### Restarting Apache web server (following installation and setup of PHP modules)"
service apache2 restart

echo "### Clean up installation"
aptitude clean

echo "### Patching ~/.bashrc"
cat << EOF >> ~/.bashrc

alias mysqlconn='mysql -u root -p testdb'
alias pgsqlconn='psql -h 127.0.0.1 -p 5432 -U postgres -W testdb'
alias oracleconn='sqlplus SYS/testpass@//127.0.0.1:1521/XE AS SYSDBA'
alias oracleconnscott='sqlplus SCOTT/testpass@//127.0.0.1:1521/XE'
alias db2conn='db2'
alias sqliteconn='sqlite /var/www/sqlmap/dbs/sqlite/testdb.sqlite'
alias sqlite3conn='sqlite3 /var/www/sqlmap/dbs/sqlite/testdb.sqlite3'
alias firebirdconn='isql-fb -u SYSDBA -p testpass /var/www/sqlmap/dbs/firebird/testdb.fdb'

alias upgradeall='aptitude update && aptitude -y full-upgrade && aptitude clean && sync'
EOF
source ~/.bashrc

