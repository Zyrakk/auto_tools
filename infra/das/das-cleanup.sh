#!/bin/bash
#===============================================================================
# DAS CLEANUP SCRIPT
# Limpia completamente el DAS: desmonta, elimina LVs y prepara para nueva config
#
# USO: sudo ./das-cleanup.sh [--force]
#===============================================================================

set -euo pipefail

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

FORCE=false
[[ "${1:-}" == "--force" ]] && FORCE=true

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#===============================================================================
# VERIFICACIONES
#===============================================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este script debe ejecutarse como root"
    fi
}

show_current_state() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    ESTADO ACTUAL DEL DAS                        ${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Logical Volumes:${NC}"
    lvs vg_das 2>/dev/null || echo "  No hay LVs en vg_das"
    echo ""
    
    echo -e "${YELLOW}Volume Group:${NC}"
    vgs vg_das 2>/dev/null || echo "  No existe vg_das"
    echo ""
    
    echo -e "${YELLOW}Puntos de montaje actuales:${NC}"
    mount | grep vg_das || echo "  Ninguno montado"
    echo ""
    
    echo -e "${YELLOW}Entradas en /etc/fstab:${NC}"
    grep -E "vg_das|/mnt/das|/mnt/chat-ai|/mnt/nfs" /etc/fstab 2>/dev/null || echo "  Ninguna encontrada"
    echo ""
    
    echo -e "${YELLOW}Exports NFS actuales:${NC}"
    cat /etc/exports 2>/dev/null | grep -v "^#" | grep -v "^$" || echo "  Ninguno"
    echo ""
}

confirm_cleanup() {
    if $FORCE; then
        return 0
    fi
    
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  ADVERTENCIA: ESTO ELIMINARÁ TODOS LOS DATOS DEL DAS ⚠️${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Se eliminarán:"
    echo "  - Todos los Logical Volumes (lv_das, lv_logs, etc.)"
    echo "  - Todos los datos contenidos en ellos"
    echo "  - Configuración NFS exports"
    echo "  - Entradas de /etc/fstab relacionadas"
    echo ""
    echo "El Volume Group (vg_das) se mantendrá para reutilizarlo."
    echo ""
    read -p "Escribe 'ELIMINAR TODO' para confirmar: " response
    
    if [[ "$response" != "ELIMINAR TODO" ]]; then
        log_info "Operación cancelada"
        exit 0
    fi
}

#===============================================================================
# PARAR SERVICIOS
#===============================================================================
stop_services() {
    log_info "Parando servicios que puedan usar el DAS..."
    
    # Parar NFS
    if systemctl is-active --quiet nfs-server 2>/dev/null; then
        systemctl stop nfs-server
        log_ok "NFS server parado"
    fi
    
    # Parar NFS kernel server (Debian/Ubuntu)
    if systemctl is-active --quiet nfs-kernel-server 2>/dev/null; then
        systemctl stop nfs-kernel-server
        log_ok "NFS kernel server parado"
    fi
}

#===============================================================================
# LIMPIAR NFS
#===============================================================================
cleanup_nfs() {
    log_info "Limpiando configuración NFS..."
    
    # Desexportar todo
    exportfs -ua 2>/dev/null || true
    
    # Limpiar /etc/exports (mantener comentarios de cabecera)
    if [[ -f /etc/exports ]]; then
        cp /etc/exports /etc/exports.backup.$(date +%Y%m%d%H%M%S)
        cat > /etc/exports << 'EOF'
# /etc/exports: the access control list for filesystems which may be exported
#               to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        guesthost(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  guesthost(rw,sync,no_subtree_check)
#

EOF
        log_ok "NFS exports limpiados (backup creado)"
    fi
}

#===============================================================================
# DESMONTAR VOLÚMENES
#===============================================================================
unmount_volumes() {
    log_info "Desmontando volúmenes..."
    
    # Lista de posibles puntos de montaje
    MOUNT_POINTS=(
        "/mnt/das"
        "/mnt/chat-ai"
        "/mnt/nfs/oracle1"
        "/mnt/nfs/oracle2"
        "/mnt/nfs/shared"
        "/mnt/nfs/temp"
        "/mnt/local"
    )
    
    for mp in "${MOUNT_POINTS[@]}"; do
        if mountpoint -q "$mp" 2>/dev/null; then
            log_info "Desmontando $mp..."
            
            # Matar procesos que usen el mount
            fuser -km "$mp" 2>/dev/null || true
            sleep 1
            
            umount -f "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
            log_ok "Desmontado: $mp"
        fi
    done
    
    # Desmontar cualquier cosa de vg_das que quede
    for lv_path in /dev/vg_das/*; do
        if [[ -e "$lv_path" ]]; then
            mp=$(findmnt -n -o TARGET "$lv_path" 2>/dev/null || true)
            if [[ -n "$mp" ]]; then
                log_info "Desmontando $lv_path de $mp..."
                fuser -km "$mp" 2>/dev/null || true
                umount -f "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
            fi
        fi
    done
    
    log_ok "Volúmenes desmontados"
}

#===============================================================================
# LIMPIAR FSTAB
#===============================================================================
cleanup_fstab() {
    log_info "Limpiando /etc/fstab..."
    
    cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d%H%M%S)
    
    # Eliminar entradas relacionadas con vg_das y nuestros puntos de montaje
    grep -vE "vg_das|/mnt/das|/mnt/chat-ai|/mnt/nfs/oracle|/mnt/nfs/shared|/mnt/nfs/temp|/mnt/local" /etc/fstab > /etc/fstab.tmp
    mv /etc/fstab.tmp /etc/fstab
    
    log_ok "fstab limpiado (backup creado)"
}

#===============================================================================
# ELIMINAR LOGICAL VOLUMES
#===============================================================================
remove_logical_volumes() {
    log_info "Eliminando Logical Volumes..."
    
    # Obtener lista de LVs en vg_das
    LVS=$(lvs --noheadings -o lv_name vg_das 2>/dev/null | tr -d ' ' || true)
    
    if [[ -z "$LVS" ]]; then
        log_info "No hay Logical Volumes que eliminar"
        return 0
    fi
    
    for lv in $LVS; do
        log_info "Eliminando LV: $lv"
        
        # Desactivar primero
        lvchange -an "vg_das/$lv" 2>/dev/null || true
        
        # Eliminar
        lvremove -f "vg_das/$lv"
        
        log_ok "Eliminado: $lv"
    done
    
    log_ok "Todos los Logical Volumes eliminados"
}

#===============================================================================
# LIMPIAR DIRECTORIOS
#===============================================================================
cleanup_directories() {
    log_info "Limpiando directorios de montaje..."
    
    DIRS_TO_CLEAN=(
        "/mnt/das"
        "/mnt/chat-ai"
        "/mnt/nfs"
        "/mnt/local"
    )
    
    for dir in "${DIRS_TO_CLEAN[@]}"; do
        if [[ -d "$dir" ]]; then
            # Verificar que no esté montado
            if ! mountpoint -q "$dir" 2>/dev/null; then
                rm -rf "$dir"
                log_ok "Eliminado: $dir"
            else
                log_warn "$dir aún está montado, no se elimina"
            fi
        fi
    done
}

#===============================================================================
# INFORME FINAL
#===============================================================================
final_report() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ DAS LIMPIADO COMPLETAMENTE${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${YELLOW}Estado del Volume Group:${NC}"
    vgs vg_das 2>/dev/null || echo "  No existe"
    echo ""
    
    echo -e "${YELLOW}Physical Volumes:${NC}"
    pvs 2>/dev/null | grep -E "PV|vg_das" || echo "  Ninguno"
    echo ""
    
    echo -e "${YELLOW}Espacio disponible:${NC}"
    vgs --noheadings -o vg_free vg_das 2>/dev/null | xargs echo "  " || echo "  N/A"
    echo ""
    
    echo "Próximo paso:"
    echo "  Ejecutar: sudo ./das-setup.sh"
    echo ""
}

#===============================================================================
# MAIN
#===============================================================================
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              DAS CLEANUP SCRIPT                            ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    show_current_state
    confirm_cleanup
    
    stop_services
    cleanup_nfs
    unmount_volumes
    cleanup_fstab
    remove_logical_volumes
    cleanup_directories
    
    final_report
}

main "$@"