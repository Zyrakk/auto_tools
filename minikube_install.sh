#!/bin/bash
set -e

echo "-----------------------------------------------------"
echo "Actualizando el sistema e instalando dependencias..."
echo "-----------------------------------------------------"
sudo apt-get update
sudo apt-get install -y curl apt-transport-https ca-certificates gnupg lsb-release

echo ""
echo "-----------------------------------------------------"
echo "Verificando la instalación de Docker..."
echo "-----------------------------------------------------"
if ! command -v docker &> /dev/null; then
  echo "Docker no está instalado. Instalando Docker..."
  # Agregar la clave GPG oficial de Docker
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  
  # Configurar el repositorio de Docker
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
else
  echo "Docker ya está instalado."
fi

echo ""
echo "-----------------------------------------------------"
echo "Verificando la instalación de kubectl..."
echo "-----------------------------------------------------"
if ! command -v kubectl &> /dev/null; then
  echo "kubectl no está instalado. Instalando kubectl..."
  # Descarga la versión estable más reciente de kubectl
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl ya está instalado."
fi

echo ""
echo "-----------------------------------------------------"
echo "Instalando Minikube..."
echo "-----------------------------------------------------"
# Descarga el binario más reciente de Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo ""
echo "-----------------------------------------------------"
echo "Iniciando Minikube con Docker como driver..."
echo "-----------------------------------------------------"
minikube start --driver=docker

echo ""
echo "-----------------------------------------------------"
echo "Estado de Minikube:"
echo "-----------------------------------------------------"
minikube status

echo ""
echo "¡Instalación completada!"
