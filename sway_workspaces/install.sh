#!/bin/bash
# Script de instalación rápida para Workspaces de Sway
# Autor: Zyrak
# Descripción: Instala y configura automáticamente todos los workspaces

set -e  # Salir si hay algún error

echo "=================================="
echo "Instalación de Workspaces para Sway"
echo "=================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sin color

# Función para mensajes
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar que estamos en Sway
if [ "$XDG_SESSION_TYPE" != "wayland" ] || [ -z "$SWAYSOCK" ]; then
    error "Este script debe ejecutarse desde una sesión de Sway"
    exit 1
fi

info "Sesión de Sway detectada correctamente"

# Obtener el directorio donde está el script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar que existen los archivos necesarios
FILES=("init-workspaces.sh" "ssh-connect.sh" "autostart" "workspace-keybindings")
for file in "${FILES[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$file" ]; then
        error "No se encuentra el archivo: $file"
        error "Asegúrate de que todos los archivos estén en el mismo directorio"
        exit 1
    fi
done

info "Todos los archivos necesarios encontrados"

# Crear directorios si no existen
info "Creando estructura de directorios..."
mkdir -p ~/.config/sway/scripts
mkdir -p ~/.config/sway/config.d

# Copiar scripts
info "Copiando scripts..."
cp "$SCRIPT_DIR/init-workspaces.sh" ~/.config/sway/scripts/
cp "$SCRIPT_DIR/ssh-connect.sh" ~/.config/sway/scripts/

# Dar permisos de ejecución
info "Configurando permisos de ejecución..."
chmod +x ~/.config/sway/scripts/init-workspaces.sh
chmod +x ~/.config/sway/scripts/ssh-connect.sh

# Copiar archivos de configuración
info "Copiando archivos de configuración..."
cp "$SCRIPT_DIR/autostart" ~/.config/sway/config.d/
cp "$SCRIPT_DIR/workspace-keybindings" ~/.config/sway/config.d/

# Verificar si Sway ya incluye config.d
if ! grep -q "include.*config.d" ~/.config/sway/config 2>/dev/null; then
    warning "El archivo config de Sway no incluye config.d"
    echo ""
    echo "Añade esta línea al final de ~/.config/sway/config:"
    echo ""
    echo "include ~/.config/sway/config.d/*"
    echo ""
    read -p "¿Quieres que lo añada automáticamente? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        echo "" >> ~/.config/sway/config
        echo "# Incluir configuraciones personalizadas" >> ~/.config/sway/config
        echo "include ~/.config/sway/config.d/*" >> ~/.config/sway/config
        info "Línea añadida a ~/.config/sway/config"
    else
        warning "Deberás añadir la línea manualmente"
    fi
fi

# Verificar dependencias
echo ""
info "Verificando dependencias..."

DEPS=("kitty" "firefox" "wofi" "mako")
MISSING_DEPS=()

for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    warning "Faltan las siguientes dependencias: ${MISSING_DEPS[*]}"
    echo ""
    echo "Para instalarlas, ejecuta:"
    echo "sudo pacman -S ${MISSING_DEPS[*]}"
    echo ""
fi

# Verificar software opcional
echo ""
info "Verificando software opcional..."

OPTIONAL=("spotify" "obsidian")
MISSING_OPTIONAL=()

for opt in "${OPTIONAL[@]}"; do
    if ! command -v "$opt" &> /dev/null; then
        MISSING_OPTIONAL+=("$opt")
    fi
done

if [ ${#MISSING_OPTIONAL[@]} -gt 0 ]; then
    warning "Software opcional no instalado: ${MISSING_OPTIONAL[*]}"
    echo ""
    echo "Para instalarlo:"
    for opt in "${MISSING_OPTIONAL[@]}"; do
        if [ "$opt" = "obsidian" ]; then
            echo "  yay -S obsidian-bin"
        else
            echo "  yay -S $opt"
        fi
    done
    echo ""
fi

# Configurar SSH
echo ""
info "Configuración del script SSH"
echo ""
echo "El archivo ~/.config/sway/scripts/ssh-connect.sh necesita ser editado"
echo "para añadir tus servidores SSH."
echo ""
read -p "¿Quieres editarlo ahora? (s/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    ${EDITOR:-nano} ~/.config/sway/scripts/ssh-connect.sh
    info "Archivo SSH configurado"
else
    warning "Recuerda editar ~/.config/sway/scripts/ssh-connect.sh más tarde"
fi

# Preguntar si quiere inicializar ahora
echo ""
info "Instalación completada"
echo ""
echo "Opciones:"
echo "1. Recargar Sway y inicializar workspaces ahora"
echo "2. Solo recargar Sway (sin inicializar workspaces)"
echo "3. No hacer nada ahora (manual)"
echo ""
read -p "Elige una opción (1/2/3): " -n 1 -r
echo

case $REPLY in
    1)
        info "Recargando Sway e inicializando workspaces..."
        swaymsg reload
        sleep 2
        ~/.config/sway/scripts/init-workspaces.sh
        info "¡Listo! Los workspaces han sido inicializados"
        ;;
    2)
        info "Recargando Sway..."
        swaymsg reload
        info "Sway recargado. Ejecuta init-workspaces.sh cuando quieras"
        ;;
    3)
        info "No se realizaron cambios en la sesión actual"
        echo "Para activar los cambios:"
        echo "  1. Recarga Sway: swaymsg reload"
        echo "  2. Ejecuta: ~/.config/sway/scripts/init-workspaces.sh"
        ;;
    *)
        warning "Opción no válida. No se realizaron cambios"
        ;;
esac

echo ""
echo "=================================="
echo "Resumen de archivos instalados:"
echo "=================================="
echo ""
echo "Scripts:"
echo "  ~/.config/sway/scripts/init-workspaces.sh"
echo "  ~/.config/sway/scripts/ssh-connect.sh"
echo ""
echo "Configuración:"
echo "  ~/.config/sway/config.d/autostart"
echo "  ~/.config/sway/config.d/workspace-keybindings"
echo ""
echo "=================================="
echo "Atajos de teclado nuevos:"
echo "=================================="
echo ""
echo "  Super + Shift + w  →  Reinicializar workspaces"
echo "  Super + Shift + s  →  Selector SSH"
echo "  Super + Shift + d  →  Abrir Workspace 2 (Dev)"
echo "  Super + Shift + o  →  Abrir Workspace 4 (Obsidian)"
echo "  Super + Shift + m  →  Abrir Workspace 8 (Multimedia)"
echo "  Super + Shift + g  →  Abrir Workspace 9 (Juegos)"
echo ""
echo "Lee el README-workspaces.md para más información"
echo ""
info "¡Instalación completada con éxito!"
