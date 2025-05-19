#!/bin/bash
set -euo pipefail

# Leemos info de la distro
. /etc/os-release

# Determinamos canal de Docker según distro
if [[ "$ID" == "ubuntu" ]] || grep -qi "ubuntu" <<<"$ID_LIKE"; then
  DOCKER_URL="https://download.docker.com/linux/ubuntu"
elif [[ "$ID" == "debian" ]] || grep -qi "debian" <<<"$ID_LIKE"; then
  DOCKER_URL="https://download.docker.com/linux/debian"
else
  echo "❌ Distro no soportada: $ID (ID_LIKE=$ID_LIKE)"
  exit 1
fi

echo "ℹ️  Detección: ID=$ID, ID_LIKE=$ID_LIKE → usando repo de ${DOCKER_URL##*/}"

echo "🧹 Eliminando paquetes antiguos..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  if dpkg -l | grep -qw "$pkg"; then
    sudo apt-get remove -y "$pkg"
  else
    echo "  – $pkg no instalado."
  fi
done

echo "🔄 Actualizando índices..."
sudo apt-get update

echo "📦 Instalando prerequisitos..."
sudo apt-get install -y ca-certificates curl acl gnupg

echo "📁 Preparando directorio de claves..."
sudo install -m0755 -d /etc/apt/keyrings

echo "🔑 Importando clave GPG de Docker..."
curl -fsSL "$DOCKER_URL/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "🔒 Ajustando permisos de la clave..."
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🌐 Añadiendo repositorio Docker (${DOCKER_URL##*/})..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  $DOCKER_URL \
  $VERSION_CODENAME stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Actualizando índices con repo Docker..."
sudo apt-get update

echo "🚀 Instalando Docker Engine y Compose plugin..."
sudo apt-get install -y \
  docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

echo "✅ Habilitando y arrancando servicios..."
sudo systemctl enable --now docker containerd

echo "👤 Añadiendo $USER al grupo docker..."
sudo usermod -aG docker "$USER" || true
sudo setfacl -m user:"$USER":rw /var/run/docker.sock || true

echo
echo "✅ ¡Hecho! Ahora cierra sesión y vuelve a entrar para activar el grupo 'docker'."
echo "   Comprueba con: docker --version && docker compose version"
