#!/bin/bash
set -euo pipefail

echo "🧹 Eliminando paquetes antiguos o en conflicto..."
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    if dpkg -l | grep -qw "$pkg"; then
        sudo apt-get remove -y "$pkg"
    else
        echo "  – $pkg no está instalado, omitiendo."
    fi
done

echo "🔄 Actualizando lista de paquetes..."
sudo apt-get update

echo "📦 Instalando dependencias necesarias..."
sudo apt-get install -y ca-certificates curl acl gnupg

echo "📁 Creando directorio para claves GPG..."
sudo install -m 0755 -d /etc/apt/keyrings

echo "🔑 Descargando la clave GPG de Docker..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "🔒 Ajustando permisos de la clave GPG..."
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "🌐 Añadiendo el repositorio oficial de Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | \
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
sudo usermod -aG docker "$USER"
# Asegura permisos en socket para evitar sudo docker todo el rato
sudo setfacl -m user:"$USER":rw /var/run/docker.sock || true

echo "🔄 Recargando permisos de grupo (cierra y vuelve a entrar al sistema para aplicar cambios)."
echo
echo "✅ Instalación completada. Comprueba las versiones con:"
echo "   docker --version"
echo "   docker compose version"
