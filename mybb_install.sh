#!/usr/bin/env bash
#
# install_mybb.sh
# Script para descargar e instalar MyBB en la ruta que pases como argumento,
# configurando permisos recomendados por MyBB.

set -euo pipefail

# ---------------------------------------------------
# Comprobaciones iniciales
# ---------------------------------------------------
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Por favor ejecuta este script como root o con sudo."
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Uso: $0 /ruta/de/instalacion [version]"
  echo "  /ruta/de/instalacion: Directorio donde MyBB será instalado."
  echo "  version: (opcional) versión de MyBB. Por defecto: 1.8.35"
  exit 1
fi

# ---------------------------------------------------
# Parámetros de instalación
# ---------------------------------------------------
INSTALL_PATH="$1"
VERSION="${2:-1.8.35}"
TARBALL="mybb-${VERSION}.tar.gz"
DOWNLOAD_URL="https://resources.mybb.com/downloads/${TARBALL}"

# ---------------------------------------------------
# Pasos de instalación
# ---------------------------------------------------
echo "🚀 Instalando MyBB v${VERSION} en ${INSTALL_PATH}..."

# 1. Crear directorio destino si no existe
mkdir -p "$INSTALL_PATH"
cd "$INSTALL_PATH"

# 2. Descargar el paquete oficial
echo "📥 Descargando ${TARBALL}..."
wget -q "$DOWNLOAD_URL" -O "$TARBALL"

# 3. Extraer contenido (quitamos la carpeta raíz del tar)
echo "📂 Descomprimiendo..."
tar -xzf "$TARBALL" --strip-components=1
rm "$TARBALL"

# ---------------------------------------------------
# Configuración de permisos
# ---------------------------------------------------
echo "🔒 Ajustando permisos genéricos..."
# Archivos a 644, directorios a 755
find . -type f -exec chmod 644 {} \;
find . -type d -exec chmod 755 {} \;

echo "✏️ Ajustando permisos de escritura para config, cache y uploads..."
# Configuración y ficheros que deben ser editables por el servidor web
chmod 666 inc/config.php inc/settings.php
chmod -R 777 cache/ uploads/ uploads/avatars/ uploads/ranks/ admin/uploads/ admin/inc/config.php

# ---------------------------------------------------
# (Opcional) Cambiar propietario
# ---------------------------------------------------
WEBUSER="www-data"
WEBGROUP="www-data"
echo "👤 Estableciendo propietario a ${WEBUSER}:${WEBGROUP} (ajusta si usas otro usuario)..."
chown -R ${WEBUSER}:${WEBGROUP} "$INSTALL_PATH"

echo "✅ ¡Listo! MyBB v${VERSION} instalado en ${INSTALL_PATH}."
echo "   Ahora visita tu servidor en el navegador y remata la instalación desde /install."
