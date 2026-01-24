#!/bin/bash
set -e

# Verificar distrobox
echo "=== Verificando distrobox ==="
if command -v distrobox &> /dev/null; then
    echo "✓ distrobox instalado: $(distrobox version)"
else
    echo "✗ distrobox no encontrado"
    exit 1
fi

# Crear contenedor si no existe
echo -e "\n=== Creando contenedor dev-tools ==="
if distrobox list | grep -q "dev-tools"; then
    echo "✓ Contenedor ya existe"
else
    distrobox create --name dev-tools --image fedora:41 -Y
    echo "✓ Contenedor creado"
fi

# Instalar Antigravity y dependencias dentro del contenedor
echo -e "\n=== Instalando Antigravity y dependencias ==="
distrobox enter dev-tools -- bash -c '
    # Añadir repo
    sudo tee /etc/yum.repos.d/antigravity.repo > /dev/null << EOL
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
EOL
    
    sudo dnf makecache -y
    sudo dnf install -y antigravity git
    echo "✓ Antigravity y git instalados"
'

# Exportar al host
echo -e "\n=== Exportando app al host ==="
distrobox enter dev-tools -- distrobox-export --app antigravity

echo -e "\n=== ¡Listo! ==="
echo "Antigravity debería aparecer en tu menú de aplicaciones KDE"
echo "También puedes ejecutarlo con: distrobox enter dev-tools -- antigravity"