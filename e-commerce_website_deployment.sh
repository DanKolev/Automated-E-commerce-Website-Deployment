#!/bin/bash
#
# This script automates the deployment of an e-commerce webiste.
#   Secures Apache and MariDB servers, as well as SSH connection.
# Author: Daniel Kolev
# email: daniel@danielkolev.org


#########################################
# Print messages in color.
# Arguments:
#   Color. eg: red or green
#########################################
function print_color(){
    NC='\033[0m' #No color

    case $1 in
        "green") COLOR="\033[0;32m" ;;
        "red") COLOR="\033[0;31m" ;;
        "*") COLOR="\033[0m" ;;
    esac    
    
    echo -e "${COLOR}$2 ${NC}"
}


#########################################
# Checks the status of a service. Error and exit if not active.
# Arguments:
# 	Service. eg: firewalld, sshd
##########################################
function check_service_status(){

    is_service_active=$(systemctl is-active $1)
    if [ $is_service_active = "active" ]
    then
        print_color "green" "$1 service is active"
    else
        print_color "red" "$1 service is not active"
    fi 
}


#########################################
# Checks if ports are enabled in the firwalld rule.
# Arguments:
# 	Ports, eg: 4406 (3306), 3322 (22)
##########################################
function confirm_firewall_port_config(){

    firewall_ports=$( firewall-cmd --list-all --zone=public | grep ports)
    
    if [[ $firewall_ports = *$1* ]]    
    then    
        print_color "green" "Port $1 has been configured"
    
    else 
        print_color "red" "Port $1 has not been configured"
    fi
}

#########################################
# Checks if item is present on the web page.
# Arguments:
# 	Webpage
# 	Items
##########################################
function check_item(){ 
    if [[ $1 = *$2* ]]

    then    
        print_color "green" "The item $2 is present on the webiste"
    else
        print_color "red" "The item $2 is not present on the website"
    fi    
}


#------SELinux

# Set SELinux Security Policies
print_color "green" "Setting SELinux Security Policies for Database network conenction, SSH and MariaDB ports..."
setsebool -P httpd_can_network_connect_db 1
semanage port -a -t ssh_port_t -p tcp 3322
semanage port -a -t mysqld_port_t -p tcp 4406

#-------Install Apache, MariaDB, Firewalld, and Fail2Ban

# Install Firewall
print_color "green" "Installing Firewalld..."
yum install firewalld -y
systemctl enable firewalld --now

# Install Dnf-Automatic
print_color "green" "Installing Dnf-Automatic..."
yum install dnf-automatic -y

# Install Apache Web Server and php
print_color "green" "Installing Apache Web Server..."
yum install -y httpd php php-common php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json

# Install MariaDB Database
print_color "green" "Installing MariaDB..."
yum install mariadb-server -y

# Install Fail2Ban
print_color "green" "Installing Fail2ban..."
yum install epel-release -y
yum install fail2ban -y


#-----Dnf-Automatic Configuration

# Configure Dnf-Automatic
print_color "green" "Configuring Dnf-Automatic to auto-install downloaded updates..."
sed -i 's/apply_updates = no/apply_updates = yes/g' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic.timer

#-------Web Server Configuration

# Configure Web Server
print_color "green" "Configuring Web Server..."
sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

# Configure Firewall Rules For Web Server
print_color "green" "Configuring Firewall rules for web server..."
firewall-cmd --add-port=80/tcp --zone=public --permanent
firewall-cmd --reload
confirm_firewall_port_config 80

# Secure Apache Server
print_color "green" "Hide version number of Apache Server..."
cat >> /etc/httpd/conf/httpd.conf <<-EOF
ServerTokens Prod
ServerSignature off
EOF

print_color "green" "Disable directory browsder listing..."
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' /etc/httpd/conf/httpd.conf

# Start/Enable HTTPD Service
print_color "green" "Starting web server..."
systemctl enable httpd --now

# Install Git and download app source code
print_color "green" "Cloning E-Commerce Website Repo..."
yum install -y git
git clone https://github.com/jacob5412/PHP-ecommerce /var/www/html/

check_service_status httpd


#-------Database Configuration

# Configure Firewall Rules For Database
print_color "green" "Changing Mariadb port to 4406..."
print_color "green" "Configuring Firewall Rules for DB..."
sed -i '/mysqld/a port = 4406' /etc/my.cnf.d/mariadb-server.cnf
firewall-cmd --add-port=4406/tcp --permanent
firewall-cmd --reload
confirm_firewall_port_config 4406

# Configure Database
print_color "green" "Configuring DB..."
 sed -i 's/#bind-address=0.0.0.0/bind-address=127.0.0.1/g' /etc/my.cnf.d/mariadb-server.cnf
#[mysqld]
#ssl-ca=/etc/mysql/certs/ca-cert.pem
#ssl-cert=/etc/mysql/certs/server-cert.pem
#ssl-key=/etc/mysql/certs/server-key.pem

 systemctl enable mariadb --now

cat > configure-db.sql <<-EOF
CREATE DATABASE ecommerce;
CREATE USER 'dbuser'@'localhost' IDENTIFIED BY 'MyNewPass';
GRANT ALL PRIVILEGES ON *.* TO 'dbuser'@'localhost';
FLUSH PRIVILEGES;
EOF

mysql < configure-db.sql

check_service_status mariadb

# Load Inventory Data into Database
print_color "green" "Loading inventory data into DB..."
sed -i "s/'root'/'dbuser'/g" /var/www/html/db.php
mysql ecommerce < /var/www/html/ecommerce.sql

mysql_db_results=$( mysql -e "use ecommerce; select * from pictures;")
if [[ $mysql_db_results = *gopro* ]]
then
    print_color "green" "The database has been loaded"

else print_color "red" "The database has not been loaded"

fi


#------SSH Configuration

# Change Default SSH Port and Configure Firewall Rules"
print_color "green" "Configuring SSH..."
print_color "green" "Changing SSH port to 3322..."
firewall-cmd --add-port=3322/tcp --permanent
sed -i 's/#Port 22/Port 3322/' /etc/ssh/sshd_config
firewall-cmd --reload
confirm_firewall_port_config 3322

print_color "green" "Disabling Empty Password and Root Login on SSH..."

# Disable root login
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

# Disable empty passwords
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# Enable only Protocol 2
#sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config

# Generate SSH keys
#ssh-keygen -t ed25519 -C "<userName>"
#ssh-copy-id -i ~/.ssh/ed25519.pub <ServerName>

#require key-based authentication
#sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

# Limit users who can SSH to the server
#echo "AllowUsers <username>" >> /etc/ssh/sshd_config


print_color "green" "Starting SSH..."
systemctl enable sshd --now &&  systemctl restart sshd

check_service_status sshd


#------ Fail2ban Configuration

# Configure Fail2ban for SSH jail
print_color "green" "Configuring Fail2ban Jail for SSH..."
cat <<EOF > /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = %(sshd_log)s
maxretry = 3
bantime = 432000
EOF

# Configure Fail2Ban for MariaDB
print_color "green" "Configuring Fail2ban Jail for MariaDB..."

cat <<EOF > /etc/fail2ban/filter.d/mariadb.conf
[Definition]
failregex = ^.*Access denied for user.* from <HOST>.*$
ignoreregex =
EOF

cat <<EOF > /etc/fail2ban/jail.d/mariadb.local
[mariadb]
enabled = true
port = 4406
filter = mariadb
logpath = /var/log/mariadb/mariadb.log
maxretry = 3
bantime = 432000
EOF

# Start Fail2Ban service
systemctl enable --now fail2ban


#------- Summary

print_color "green" "Summary..."

check_service_status firewalld
check_service_status dnf-automatic.timer
check_service_status mariadb
check_service_status httpd
check_service_status sshd
check_service_status fail2ban

confirm_firewall_port_config 80
confirm_firewall_port_config 4406
confirm_firewall_port_config 3322


#-------Test

print_color "green" "Test"

web_page=$(curl http://localhost)

for item in Watch Gopro Laptop Speaker
do
    "check_item" "$web_page" $item
done 

print_color "green" "\nIf items are present, you should be all set.\n"

