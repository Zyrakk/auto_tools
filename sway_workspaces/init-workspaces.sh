#!/bin/bash
# Script de inicialización de workspaces para Sway
# Autor: Zyrak
# Descripción: Configura automáticamente los 7 workspaces personalizados

# Función para esperar a que una ventana aparezca
wait_for_window() {
    sleep 0.5
}

# Función para esperar más tiempo (apps pesadas)
wait_for_heavy_app() {
    sleep 1.5
}

# Workspace 1: 3 Terminales (2 arriba, 1 abajo)
echo "Configurando Workspace 1: Terminales..."
swaymsg "workspace number 1"
swaymsg "layout splith"  # Layout horizontal para las dos primeras
kitty &
wait_for_window
kitty &
wait_for_window
swaymsg "layout splitv"  # Cambiar a vertical para la tercera
swaymsg "focus parent"   # Subir al contenedor padre
kitty &
wait_for_window

# Workspace 2: Entorno Dev (mitad terminal, mitad navegador)
echo "Configurando Workspace 2: Entorno Dev..."
swaymsg "workspace number 2"
swaymsg "layout splith"  # División horizontal 50/50
kitty &
wait_for_window
firefox &
wait_for_heavy_app  # Firefox necesita más tiempo

# Workspace 3: Terminales SSH (3 columnas verticales)
echo "Configurando Workspace 3: SSH..."
swaymsg "workspace number 3"
swaymsg "layout splith"  # Layout horizontal para 3 columnas
kitty --title "SSH-1" &
wait_for_window
kitty --title "SSH-2" &
wait_for_window
kitty --title "SSH-3" &
wait_for_window

# Workspace 4: Documentación (vacío, listo para Obsidian)
echo "Configurando Workspace 4: Documentación..."
swaymsg "workspace number 4"
# Este workspace se deja vacío intencionalmente
# El usuario abrirá Obsidian u otras herramientas manualmente

# Workspace 5: Landing/Herramientas propias (vacío por defecto)
echo "Configurando Workspace 5: Landing..."
swaymsg "workspace number 5"
# Este es el workspace landing, se deja completamente vacío

# Workspace 8: Multimedia
echo "Configurando Workspace 8: Multimedia..."
swaymsg "workspace number 8"
# Solo abrimos Spotify si está instalado
if command -v spotify &> /dev/null; then
    echo "Abriendo Spotify..."
    spotify &
    wait_for_heavy_app  # Spotify también necesita más tiempo
else
    echo "Spotify no está instalado. Workspace 8 quedará vacío."
    echo "Instala Spotify con: yay -S spotify"
fi

# Workspace 9: Juegos (vacío, se abrirán manualmente)
echo "Configurando Workspace 9: Juegos..."
swaymsg "workspace number 9"
# Este workspace se deja vacío intencionalmente
# El usuario abrirá Steam/Minecraft/etc manualmente

# Regresar al workspace 5 (landing)
echo "Posicionando en Workspace 5 (Landing)..."
sleep 1
swaymsg "workspace number 5"

echo "✓ Configuración de workspaces completada!"
echo "Estás en el Workspace 5 (Landing)"
