# Wazuh SIEM Stack para ZCloud

## Descripción

Este stack despliega Wazuh 4.9.2 en tu cluster k3s con la siguiente arquitectura:

```
                Internet
                    │
                    ▼
         wazuh.zyrak.cloud (Traefik)
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼
┌─────────┐   ┌─────────────┐   ┌─────────────┐
│Dashboard│◄──│   Manager   │◄──│   Indexer   │
│  :5601  │   │  :1514/55k  │   │   :9200     │
└─────────┘   └──────┬──────┘   └─────────────┘
                     │
       ┌─────────────┼─────────────┐
       │             │             │
       ▼             ▼             ▼
   ┌───────┐    ┌───────┐    ┌───────┐
   │ Agent │    │ Agent │    │ Agent │
   │ lake  │    │oracle1│    │oracle2│
   └───────┘    └───────┘    └───────┘
```

## Componentes

| Componente | Imagen | Descripción |
|------------|--------|-------------|
| **Wazuh Indexer** | wazuh/wazuh-indexer:4.9.2 | OpenSearch modificado para almacenar alertas y logs |
| **Wazuh Manager** | wazuh/wazuh-manager:4.9.2 | Cerebro del SIEM, recibe datos de agentes, genera alertas |
| **Wazuh Dashboard** | wazuh/wazuh-dashboard:4.9.2 | Interfaz web (basada en OpenSearch Dashboards) |
| **Wazuh Agent** | wazuh/wazuh-agent:4.9.2 | DaemonSet que corre en cada nodo del cluster |

## Almacenamiento

Usa tu StorageClass `nfs-shared` existente:

| PVC | Tamaño | Uso |
|-----|--------|-----|
| wazuh-indexer-data | 50Gi | Índices y alertas |
| wazuh-manager-data | 20Gi | Configuración, reglas, agentes |
| wazuh-manager-logs | 10Gi | Logs y colas |
| wazuh-certs | 1Gi | Certificados TLS internos |

## Credenciales (CAMBIAR ANTES DE DESPLEGAR)

Edita `00-namespace-secrets.yaml`:

```yaml
WAZUH_API_USER: "wazuh-wui"
WAZUH_API_PASSWORD: "ZCloud-Wazuh-2026!"     # Dashboard -> Manager API
INDEXER_USERNAME: "admin"
INDEXER_PASSWORD: "ZCloud-Indexer-2026!"     # Login del Dashboard
WAZUH_AUTHD_PASS: "ZCloud-Agent-Enroll-2026!" # Enrollment de agentes
```

## Despliegue

### Prerrequisitos

1. **DNS en Cloudflare**: Añadir registro A para `wazuh.zyrak.cloud` apuntando a las IPs de oracle1 y oracle2
2. **cert-manager**: Ya configurado con ClusterIssuer `letsencrypt-prod`
3. **Traefik**: Ya corriendo como Ingress

### Pasos

```bash
# Desde tu máquina local
cd wazuh-stack

# Opción 1: Script automático
chmod +x deploy.sh
./deploy.sh

# Opción 2: Manual paso a paso
zcloud apply 00-namespace-secrets.yaml
zcloud apply 01-storage.yaml
zcloud apply 02-indexer.yaml
# Esperar ~2 min
zcloud apply 03-manager.yaml
# Esperar ~2 min
zcloud apply 04-dashboard.yaml
zcloud apply 05-ingress.yaml
zcloud apply 06-agent-daemonset.yaml
```

### Verificar despliegue

```bash
# Estado de pods
zcloud k get pods -n wazuh

# Logs del indexer
zcloud k logs -n wazuh deploy/wazuh-indexer

# Logs del manager
zcloud k logs -n wazuh deploy/wazuh-manager

# Logs del dashboard
zcloud k logs -n wazuh deploy/wazuh-dashboard

# Agentes corriendo
zcloud k get pods -n wazuh -l app=wazuh-agent -o wide

# Certificado TLS
zcloud k get certificate -n wazuh
```

## Acceso

- **URL**: https://wazuh.zyrak.cloud
- **Usuario**: `admin`
- **Password**: `ZCloud-Indexer-2026!` (o el que hayas configurado)

## Qué monitoriza

### File Integrity Monitoring (FIM)
- `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/sudoers` (realtime)
- `/etc`, `/usr/bin`, `/usr/sbin`, `/bin`, `/sbin`
- `/etc/rancher` (configuración k3s)
- `/var/lib/rancher/k3s/server` (datos k3s)

### Log Analysis
- `/var/log/syslog`
- `/var/log/auth.log`
- `/var/log/kern.log`
- `/var/log/audit/audit.log` (si auditd está activo)
- `/var/log/containers/*.log` (logs de containers)
- `/var/log/k3s.log`

### Security Checks
- Rootkit detection
- Vulnerability scanning (CVEs en paquetes instalados)
- Security Configuration Assessment (CIS benchmarks)
- Container/Docker monitoring

### Inventory (Syscollector)
- Hardware info
- OS info
- Network interfaces
- Installed packages
- Open ports
- Running processes

## Troubleshooting

### Indexer no arranca
```bash
# Verificar si el init container generó los certificados
zcloud k logs -n wazuh deploy/wazuh-indexer -c generate-certs

# Verificar permisos
zcloud k logs -n wazuh deploy/wazuh-indexer -c fix-permissions

# Verificar si el PVC está montado
zcloud k describe pvc wazuh-indexer-data -n wazuh
```

### Manager no conecta al Indexer
```bash
# Verificar conectividad
zcloud k exec -n wazuh deploy/wazuh-manager -- curl -sk https://wazuh-indexer:9200

# Ver logs de Filebeat (integrado en manager)
zcloud k exec -n wazuh deploy/wazuh-manager -- cat /var/ossec/logs/filebeat.log
```

### Agentes no se registran
```bash
# Ver logs del agente en un nodo específico
zcloud k logs -n wazuh -l app=wazuh-agent --all-containers

# Verificar que el manager está escuchando
zcloud k exec -n wazuh deploy/wazuh-manager -- netstat -tlnp | grep 1515

# Listar agentes registrados
zcloud k exec -n wazuh deploy/wazuh-manager -- /var/ossec/bin/agent_control -l
```

### Dashboard no carga
```bash
# Verificar conectividad al indexer
zcloud k exec -n wazuh deploy/wazuh-dashboard -- curl -sk https://wazuh-indexer:9200

# Verificar Ingress
zcloud k get ingress -n wazuh
zcloud k describe ingress wazuh-dashboard -n wazuh

# Verificar certificado
zcloud k get certificate -n wazuh
zcloud k describe certificate wazuh-tls -n wazuh
```

## Mantenimiento

### Backup
```bash
# Los datos críticos están en los PVCs:
# - wazuh-indexer-data: Alertas e índices
# - wazuh-manager-data: Configuración y reglas

# Crear snapshot del PVC (si tu storage lo soporta)
zcloud k get pvc -n wazuh
```

### Actualización
```bash
# Cambiar la versión de imagen en los yamls y reaplicar
# Wazuh recomienda actualizar en orden: Indexer -> Manager -> Dashboard -> Agents
```

### Añadir reglas personalizadas
```bash
# Copiar regla al manager
zcloud cp local_rules.xml wazuh-manager:/var/ossec/etc/rules/local_rules.xml

# Reiniciar manager
zcloud k rollout restart deployment/wazuh-manager -n wazuh
```

## Integración con tu stack

### Alertas a Telegram (futuro)
Wazuh soporta integraciones. Puedes configurar en `/var/ossec/etc/ossec.conf`:
```xml
<integration>
  <name>custom-telegram</name>
  <hook_url>https://api.telegram.org/bot<TOKEN>/sendMessage</hook_url>
  <level>10</level>
  <alert_format>json</alert_format>
</integration>
```

### Métricas a VictoriaMetrics
El Wazuh API expone métricas que puedes scrapear. Añadir ServiceMonitor si tienes Prometheus Operator.

## Notas de seguridad

1. **Cambia las contraseñas por defecto** antes de desplegar
2. Los agentes usan **enrollment automático** con contraseña compartida
3. Las comunicaciones internas usan **TLS auto-firmado** (suficiente para cluster interno)
4. El Dashboard está expuesto via HTTPS con **Let's Encrypt**
5. Los NodePorts 31514/31515 están abiertos para agentes externos (si los necesitas)

## Archivos

```
wazuh-stack/
├── 00-namespace-secrets.yaml   # Namespace + credenciales
├── 01-storage.yaml             # PVCs para datos
├── 02-indexer.yaml             # Wazuh Indexer (OpenSearch)
├── 03-manager.yaml             # Wazuh Manager + Filebeat
├── 04-dashboard.yaml           # Wazuh Dashboard (UI)
├── 05-ingress.yaml             # Ingress + Certificate
├── 06-agent-daemonset.yaml     # Agentes en cada nodo
├── deploy.sh                   # Script de despliegue
└── README.md                   # Esta documentación
```