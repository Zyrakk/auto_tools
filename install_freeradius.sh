#!/usr/bin/env bash
#
# Script de instalación y configuración básica de FreeRADIUS + MySQL + Apache (LAMP)
# en Ubuntu 24.04, con inserción de un usuario de prueba y test de radtest.
#
# NOTA: Este script es solo un ejemplo. Ajusta contraseñas, nombres de usuario,
#       IPs y otros parámetros a tus necesidades.
#

#############################
#       CONFIGURACIÓN       #
#############################

# Credenciales para MySQL
DB_ROOT_PASS="root"     # Pon aquí la contraseña que desees para el root de MySQL/MariaDB
DB_RADIUS_NAME="radius"
DB_RADIUS_USER="radius"
DB_RADIUS_PASS="radius"  # Contraseña para el usuario 'radius'

# Usuario de prueba en FreeRADIUS
RADIUS_TEST_USER="cliente"      # Nombre de usuario que crearemos en radcheck
RADIUS_TEST_PASS="pass"         # Contraseña de ese usuario
NAS_SECRET="testing123"         # Secreto compartido con el NAS (por defecto 'testing123')

# IP/host del NAS. Si solo probarás en localhost, puedes dejarlo en 127.0.0.1
NAS_IPADDR="127.0.0.1"

#############################
#     COMPROBACIONES        #
#############################

if [[ $EUID -ne 0 ]]; then
  echo "Este script debe ejecutarse como root o con sudo."
  exit 1
fi

# Simple función para pausar en pantalla
function pausa() {
  read -r -p "Presiona Enter para continuar..."
}

echo "------------------------------------------------------"
echo "  Script de instalación y configuración de FreeRADIUS"
echo "------------------------------------------------------"
echo

#############################
#       ACTUALIZACIÓN       #
#############################

echo "[1/9] Actualizando paquetes del sistema..."
apt update -y && apt upgrade -y

#############################
#       INSTALAR LAMP       #
#############################

echo "[2/9] Instalando Apache..."
apt install -y apache2
systemctl enable --now apache2

echo "[3/9] Instalando PHP y módulos..."
apt install -y php libapache2-mod-php php-gd php-common php-mail php-mail-mime php-mysql php-pear php-db php-mbstring php-xml php-curl

echo "[4/9] Instalando MySQL (o MariaDB)..."
# Puedes elegir mariadb-server en vez de mysql-server si lo prefieres
apt install -y mysql-server

echo "Habilitando arranque de MySQL..."
systemctl enable --now mysql

# OJO: La configuración de la contraseña root de MySQL de forma no interactiva
# depende de si Ubuntu 24.04 viene con la autenticación por socket o no.
# Para un entorno de pruebas, a veces basta con no definir nada.
# Para un entorno real, se recomienda usar 'mysql_secure_installation' (paso manual).

#############################
#   CONFIGURACIÓN MySQL     #
#############################

echo "[5/9] Creando base de datos y usuario para FreeRADIUS..."

# Creación de DB y usuario. Usamos EOF con la contraseña root configurada en DB_ROOT_PASS.
# IMPORTANTE: Si tu MySQL usa autenticación por socket, puede que debas quitar '-p${DB_ROOT_PASS}'
# y autenticarte manualmente.

mysql -u root -p${DB_ROOT_PASS} <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_RADIUS_NAME};
CREATE USER IF NOT EXISTS '${DB_RADIUS_USER}'@'localhost' IDENTIFIED BY '${DB_RADIUS_PASS}';
GRANT ALL PRIVILEGES ON ${DB_RADIUS_NAME}.* TO '${DB_RADIUS_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

#############################
#     INSTALAR FREERADIUS   #
#############################

echo "[6/9] Instalando FreeRADIUS y módulos MySQL..."
apt install -y freeradius freeradius-mysql freeradius-utils

echo "Deteniendo servicio de FreeRADIUS para configuraciones..."
systemctl stop freeradius

echo "[7/9] Configurando FreeRADIUS con MySQL..."
# Importamos el esquema de tablas de FreeRADIUS a la base 'radius'
mysql -u root -p${DB_ROOT_PASS} ${DB_RADIUS_NAME} < /etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql

# Habilitamos el módulo SQL
if [ ! -L /etc/freeradius/3.0/mods-enabled/sql ]; then
  ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
fi

# Ajustes en /etc/freeradius/3.0/mods-enabled/sql:
# - dialect = "mysql"
# - driver = "rlm_sql_${dialect}"
# - Descomentar "server = localhost", "login = radius", "password = radius", "radius_db = radius"
# - read_clients = yes
# - Comentar bloque TLS
sed -i 's/dialect = "sqlite"/dialect = "mysql"/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/driver = "rlm_sql_null"/driver = "rlm_sql_${dialect}"/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/#.*read_clients = yes/read_clients = yes/g' /etc/freeradius/3.0/mods-enabled/sql

# Configurar credenciales MySQL en /etc/freeradius/3.0/mods-enabled/sql
sed -i "s/#.*server = \"localhost\"/server = \"localhost\"/g" /etc/freeradius/3.0/mods-enabled/sql
sed -i "s/#.*login = \"radius\"/login = \"${DB_RADIUS_USER}\"/g" /etc/freeradius/3.0/mods-enabled/sql
sed -i "s/#.*password = \"radpass\"/password = \"${DB_RADIUS_PASS}\"/g" /etc/freeradius/3.0/mods-enabled/sql
sed -i "s/radius_db = \"radius\"/radius_db = \"${DB_RADIUS_NAME}\"/g" /etc/freeradius/3.0/mods-enabled/sql

# Comentar el bloque TLS entero (líneas que contengan "tls {", "ca_file", etc.)
sed -i 's/^\(\s*\)tls {/\1#tls {/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)ca_file/\1#ca_file/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)ca_path/\1#ca_path/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)certificate_file/\1#certificate_file/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)private_key_file/\1#private_key_file/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)cipher/\1#cipher/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)tls_required/\1#tls_required/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)tls_check_cert/\1#tls_check_cert/g' /etc/freeradius/3.0/mods-enabled/sql
sed -i 's/^\(\s*\)tls_check_cert_cn/\1#tls_check_cert_cn/g' /etc/freeradius/3.0/mods-enabled/sql
# Cerramos la llave
sed -i 's/^\(\s*\)}/\1#}/g' /etc/freeradius/3.0/mods-enabled/sql

# Ajustamos permisos
chgrp -h freerad /etc/freeradius/3.0/mods-available/sql
chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql

#############################
#   CONFIGURAR CLIENTS.CONF #
#############################

echo "[8/9] Configurando NAS en /etc/freeradius/3.0/clients.conf..."

# Añadimos (o modificamos) un bloque client al final del archivo
# para que reconozca peticiones desde 127.0.0.1 (o la IP que quieras).
CLIENTS_FILE="/etc/freeradius/3.0/clients.conf"
if ! grep -q "client MyNAS" "$CLIENTS_FILE"; then
  cat <<EOF >> "$CLIENTS_FILE"

client MyNAS {
  ipaddr = ${NAS_IPADDR}
  secret = ${NAS_SECRET}
  proto = *
}
EOF
fi

#############################
#     CREAR USUARIO TEST    #
#############################

echo "[9/9] Creando usuario de prueba en la base de datos radcheck..."

mysql -u root -p${DB_ROOT_PASS} ${DB_RADIUS_NAME} <<EOF
INSERT INTO radcheck (username, attribute, op, value)
VALUES ('${RADIUS_TEST_USER}', 'MD5-Password', ':=', MD5('${RADIUS_TEST_PASS}'));
EOF

echo "Usuario '${RADIUS_TEST_USER}' con contraseña '${RADIUS_TEST_PASS}' creado en la tabla radcheck (MD5)."

#############################
#   ARRANCAR FREERADIUS     #
#############################

echo "Arrancando servicio FreeRADIUS..."
systemctl enable freeradius
systemctl start freeradius

echo
echo "---------------------------------------------------------"
echo "       INSTALACIÓN Y CONFIGURACIÓN FINALIZADAS"
echo "---------------------------------------------------------"
echo "MySQL root pass:          ${DB_ROOT_PASS}"
echo "Base de datos RADIUS:     ${DB_RADIUS_NAME}"
echo "Usuario RADIUS:           ${DB_RADIUS_USER}"
echo "Pass RADIUS:              ${DB_RADIUS_PASS}"
echo
echo "Usuario de prueba:        ${RADIUS_TEST_USER}"
echo "Contraseña de prueba:     ${RADIUS_TEST_PASS}"
echo "Secreto NAS:              ${NAS_SECRET}"
echo
echo "Puedes probar la conexión con:"
echo "  radtest -x ${RADIUS_TEST_USER} ${RADIUS_TEST_PASS} 127.0.0.1 0 ${NAS_SECRET}"
echo
echo "Recuerda revisar los pasos manuales para completar la configuración."
echo
