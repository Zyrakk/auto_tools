#!/bin/bash
# Script selector de SSH para Workspace 3
# Autor: Zyrak
# Descripción: Selector interactivo de servidores SSH usando wofi

# Define tus servidores SSH aquí
# Formato: "Nombre|usuario@host|puerto"
SERVERS=(
    "Oracle Cloud|usuario@ip_oracle|22"
    "Raspberry Pi 5|usuario@ip_raspberry|22"
    "Mini Server 1|usuario@ip_mini1|22"
    "Mini Server 2|usuario@ip_mini2|22"
    # Añade más servidores según necesites
)

# Función para extraer datos del servidor
get_server_name() {
    echo "$1" | cut -d'|' -f1
}

get_server_connection() {
    echo "$1" | cut -d'|' -f2
}

get_server_port() {
    echo "$1" | cut -d'|' -f3
}

# Crear lista para wofi
server_list=""
for server in "${SERVERS[@]}"; do
    name=$(get_server_name "$server")
    server_list="${server_list}${name}\n"
done

# Mostrar selector con wofi
selected=$(echo -e "$server_list" | wofi --show dmenu --prompt "Conectar a servidor:")

# Si se seleccionó algo
if [ -n "$selected" ]; then
    # Buscar el servidor seleccionado
    for server in "${SERVERS[@]}"; do
        name=$(get_server_name "$server")
        if [ "$name" = "$selected" ]; then
            connection=$(get_server_connection "$server")
            port=$(get_server_port "$server")
            
            # Abrir kitty con SSH
            kitty --title "SSH: $name" ssh -p "$port" "$connection" &
            
            # Mensaje de confirmación
            notify-send "SSH" "Conectando a $name..." -t 2000
            break
        fi
    done
fi
