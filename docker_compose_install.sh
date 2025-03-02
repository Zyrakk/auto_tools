#!/bin/bash

# Script para limpiar paquetes obsoletos, añadir la clave GPG y el repositorio oficial de Docker en Ubuntu, e instalar Docker y Docker Compose

set -e  # Detiene el script si ocurre algún error

echo "🧹 Eliminando paquetes antiguos o en conflicto..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do 
    sudo apt-get remove -y $pkg 
done

echo "🔄 Actualizando lista de paquetes..."
sudo apt update

echo "📦 Instalando dependencias necesarias..."
sudo apt install -y ca-certificates curl

echo "📁 Creando directorio para claves GPG..."
sudo install -m 0755 -d /etc/apt/keyrings

echo "🔑 Descargando la clave GPG de Docker..."
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

echo "🔒 Ajustando permisos de la clave GPG..."
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "🌐 Añadiendo el repositorio oficial de Docker..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "🔄 Actualizando lista de paquetes con el nuevo repositorio..."
sudo apt update

echo "🚀 Instalando Docker y Docker Compose..."
sudo apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

echo "✅ Habilitando servicios de Docker y containerd..."
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

echo "🔄 Reiniciando servicios..."
sudo systemctl daemon-reexec
sudo systemctl restart docker

echo "📌 Estado de Docker:"
sudo systemctl status docker

echo "✅ Instalación completada. Verifica con:"
echo "   docker --version"
echo "   docker compose version"
