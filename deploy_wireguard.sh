#!/bin/bash
# Script para desplegar WireGuard en Ubuntu 24.04 (Desktop) con interfaz enp0s3.
# Debe ejecutarse con privilegios de root.

set -e  # Salir ante cualquier error

# Comprobamos si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
    echo "Este script debe ejecutarse como root." >&2
    exit 1
fi

# Actualizamos el sistema e instalamos WireGuard
echo "Actualizando paquetes e instalando WireGuard..."
apt update && apt upgrade -y
apt install -y wireguard resolvconf

# Directorio de configuración de WireGuard
WG_DIR="/etc/wireguard"
mkdir -p "${WG_DIR}"
cd "${WG_DIR}"

# Establecemos permisos para que las claves solo sean legibles por root
umask 077

echo "Generando claves del servidor..."
# Generación de par de claves del servidor
wg genkey | tee 00_server_clave_privada > /dev/null
wg pubkey < 00_server_clave_privada | tee 00_server_clave_publica > /dev/null

echo "Generando claves del cliente..."
# Generación de par de claves del cliente
wg genkey | tee 01_client_clave_privada > /dev/null
wg pubkey < 01_client_clave_privada | tee 01_client_clave_publica > /dev/null

# Leemos las claves generadas
SERVER_PRIV_KEY=$(cat 00_server_clave_privada)
CLIENT_PUB_KEY=$(cat 01_client_clave_publica)
CLIENT_PRIV_KEY=$(cat 01_client_clave_privada)
SERVER_PUB_KEY=$(cat 00_server_clave_publica)

# Configuración de IPs para el túnel
SERVER_IP="10.0.0.1/32"
CLIENT_IP="10.0.0.2/32"
LISTEN_PORT="51820"
DEFAULT_IF="enp0s3"

echo "Creando archivo de configuración del servidor en ${WG_DIR}/wg0.conf..."
cat > wg0.conf <<EOF
[Interface]
PrivateKey = ${SERVER_PRIV_KEY}
Address = ${SERVER_IP}
ListenPort = ${LISTEN_PORT}
# Regla para reenviar tráfico y NAT:
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${DEFAULT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${DEFAULT_IF} -j MASQUERADE

[Peer]
# Clave pública del cliente
PublicKey = $(cat 01_client_clave_publica)
AllowedIPs = ${CLIENT_IP}
EOF

echo "Creando archivo de configuración del cliente en ${WG_DIR}/wg0-client.conf..."
cat > wg0-client.conf <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_IP}
DNS = 8.8.8.8

[Peer]
# Clave pública del servidor
PublicKey = ${SERVER_PUB_KEY}
AllowedIPs = 0.0.0.0/0
# Reemplaza <IP_DEL_SERVIDOR> por la IP pública o dominio de tu servidor
Endpoint = <IP_DEL_SERVIDOR>:${LISTEN_PORT}
EOF

echo "Habilitando reenvío de paquetes IPv4..."
# Activar reenvío de paquetes de forma temporal
sysctl -w net.ipv4.ip_forward=1

# Levantamos la interfaz WireGuard y activamos su inicio al arrancar
echo "Levantando la interfaz wg0..."
wg-quick up wg0
systemctl enable wg-quick@wg0

echo "WireGuard se ha desplegado correctamente."
echo ""
echo "Archivo de configuración del servidor: ${WG_DIR}/wg0.conf"
echo "Archivo de configuración del cliente: ${WG_DIR}/wg0-client.conf"
echo ""
echo "Recuerda editar el archivo de cliente (wg0-client.conf) y reemplazar <IP_DEL_SERVIDOR> por la IP pública o dominio real de tu servidor."
