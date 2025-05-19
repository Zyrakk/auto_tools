#!/bin/bash
set -euo pipefail

. /etc/os-release
if [[ "$ID" == "debian" ]]; then
  DOCKER_CHANNEL_URL="https://download.docker.com/linux/debian"
elif [[ "$ID" == "ubuntu" ]]; then
  DOCKER_CHANNEL_URL="https://download.docker.com/linux/ubuntu"
else
  echo "Distro no soportada: $ID"
  exit 1
fi

echo "🧹 Eliminando paquetes antiguos o en conflicto..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    if dpkg -l | grep -qw "$pkg"; then
        sudo apt-get remove -y "$pkg"
    else
        echo "  – $pkg no instalado, omitiendo."
    fi
done

echo "🔄 Actualizando lista de paquetes..."
sudo apt-get update

echo "📦 Instalando dependencias necesarias..."
sudo apt-get install -y ca-certificates curl acl gnupg

echo "📁 Creando directorio para claves GPG..."
sudo install -m 0755 -d /etc/apt/keyrings

echo "🔑 Descargando la clave GPG de Docker..."
curl -fsSL "${DOCKER_CHANNEL_URL}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "🔒 Ajustando permisos de la clave GPG..."
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🌐 Añadiendo el repositorio oficial de Docker para $ID..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  ${DOCKER_CHANNEL_URL} \
  $(echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Actualizando lista de paquetes con el nuevo repositorio..."
sudo apt-get update

echo "🚀 Instalando Docker Engine y Docker Compose Plugin..."
sudo apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

echo "✅ Habilitando servicios de Docker y containerd..."
sudo systemctl enable --now docker containerd

echo "📋 Añadiendo el usuario actual al grupo 'docker'..."
sudo usermod -aG docker "$USER" || true
sudo setfacl -m user:"$USER":rw /var/run/docker.sock || true

echo
echo "✅ ¡Listo! Cierra sesión y vuelve a entrar para que los cambios de grupo surtan efecto."
echo "   Comprueba con: docker --version && docker compose version"
