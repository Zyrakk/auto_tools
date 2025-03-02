#!/bin/bash
# Script para instalar y configurar FreeRADIUS con MySQL en Ubuntu 24.04
# Se requiere ejecutar este script con privilegios de root o usando sudo.
# Algunas configuraciones avanzadas (como TLS, daloRADIUS, etc.) deberán hacerse manualmente.

set -e

# VARIABLES DE CONFIGURACIÓN
DB_NAME="radius"
DB_USER="radius"
DB_PASS="radius"
TEST_USER="cliente"
TEST_USER_PASS="pass"
NAS_SECRET="testing123"   # Clave compartida definida en /etc/freeradius/3.0/clients.conf
SQL_MODULE_FILE="/etc/freeradius/3.0/mods-enabled/sql"

echo "Actualizando repositorios..."
apt update

echo "Instalando FreeRADIUS, módulos SQL y MySQL Server..."
apt -y install freeradius freeradius-mysql freeradius-utils mysql-server

echo "Deteniendo FreeRADIUS para aplicar configuraciones..."
systemctl stop freeradius

echo "Configurando base de datos MySQL para FreeRADIUS..."
sudo mysql <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Importar el esquema SQL de FreeRADIUS
SCHEMA_FILE="/etc/freeradius/3.0/mods-config/sql/main/mysql/schema.sql"
if [ -f "$SCHEMA_FILE" ]; then
    echo "Importando el esquema SQL de FreeRADIUS..."
    mysql ${DB_NAME} < "$SCHEMA_FILE"
else
    echo "No se encontró el archivo de esquema: $SCHEMA_FILE"
fi

# Habilitar el módulo SQL (crear enlace simbólico si no existe)
if [ ! -L /etc/freeradius/3.0/mods-enabled/sql ]; then
    echo "Habilitando módulo SQL..."
    ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql
fi

echo "Configurando el módulo SQL de FreeRADIUS..."
# Cambiar el dialecto de sqlite a mysql
sed -i 's/^\s*dialect\s*=.*"sqlite"/dialect = "mysql"/' ${SQL_MODULE_FILE}
# Cambiar el driver a rlm_sql_mysql
sed -i 's/^\s*driver\s*=.*"rlm_sql_null"/driver = "rlm_sql_mysql"/' ${SQL_MODULE_FILE}

# Descomentar y establecer los parámetros de conexión
sed -i 's/^#\s*\(server\s*=\s*"\)localhost"/\1localhost"/' ${SQL_MODULE_FILE}
sed -i 's/^#\s*\(port\s*=\s*\)3306/\13306/' ${SQL_MODULE_FILE}
sed -i 's/^#\s*\(login\s*=\s*"\)[^"]*"/login = "'"${DB_USER}"'"/' ${SQL_MODULE_FILE}
sed -i 's/^#\s*\(password\s*=\s*"\)[^"]*"/password = "'"${DB_PASS}"'"/' ${SQL_MODULE_FILE}

# Asegurar que la base de datos se establezca correctamente
sed -i 's/^\s*#\?\s*radius_db\s*=.*$/radius_db = "'"${DB_NAME}"'"/' ${SQL_MODULE_FILE}

# Descomentar read_clients = yes y client_table = "nas"
sed -i 's/^#\s*\(read_clients\s*=\s*yes\)/\1/' ${SQL_MODULE_FILE}
sed -i 's/^#\s*\(client_table\s*=\s*".*"\)/\1/' ${SQL_MODULE_FILE}

# Ajustar permisos para el módulo SQL
chgrp -h freerad /etc/freeradius/3.0/mods-available/sql || true
chown -R freerad:freerad /etc/freeradius/3.0/mods-enabled/sql || true

echo "Reiniciando FreeRADIUS..."
systemctl restart freeradius

echo "Insertando usuario de prueba en la base de datos..."
sudo mysql <<EOF
USE ${DB_NAME};
INSERT INTO radcheck (username, attribute, op, value) VALUES ('${TEST_USER}', 'MD5-Password', ':=', MD5('${TEST_USER_PASS}'));
EOF

# Esperar unos segundos para asegurarse de que FreeRADIUS esté corriendo
sleep 5

echo "Ejecutando prueba con radtest..."
radtest -x ${TEST_USER} ${TEST_USER_PASS} 127.0.0.1 0 ${NAS_SECRET}

echo "-----------------------------------------"
echo "La instalación y prueba han finalizado."
echo "Si en la salida de radtest aparece 'Access-Accept', FreeRADIUS está funcionando correctamente."

echo ""
echo "Pasos Manuales / Configuraciones Adicionales:"
echo "  - Revisa el archivo /etc/freeradius/3.0/mods-enabled/sql para ajustar otras opciones si es necesario."
echo "  - Configura /etc/freeradius/3.0/clients.conf para agregar otros clientes NAS según tus necesidades."
echo "  - La configuración de TLS y la instalación de daloRADIUS (panel web) requieren pasos adicionales manuales."
