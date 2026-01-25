# ZCloud Monitoring Stack

Stack de monitorización para el cluster k3s de ZCloud.

## Componentes

| Componente | Versión | Descripción |
|------------|---------|-------------|
| Node Exporter | v1.7.0 | Métricas de sistema (CPU, RAM, disco, red) de cada nodo |
| Kube State Metrics | v2.10.1 | Métricas de objetos Kubernetes (pods, deployments, etc) |
| VictoriaMetrics | v1.96.0 | Backend de métricas (compatible Prometheus, más eficiente) |
| Grafana | v10.3.1 | Dashboards y visualización |

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLUSTER K3S                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │   lake   │  │ oracle1  │  │ oracle2  │  │raspberry │        │
│  │  (N150)  │  │          │  │          │  │   (Pi5)  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       │             │             │             │               │
│       └──────────┬──┴─────────────┴─────────────┘               │
│                  │                                               │
│           ┌──────▼──────┐                                       │
│           │Node Exporter│  (DaemonSet - 1 por nodo)             │
│           │    :9100    │                                       │
│           └──────┬──────┘                                       │
│                  │                                               │
│    ┌─────────────┼─────────────┐                                │
│    │             │             │                                │
│    ▼             ▼             ▼                                │
│ ┌──────┐  ┌─────────────┐  ┌──────────────────┐                │
│ │ KSM  │  │VictoriaMetrics│  │     Grafana      │               │
│ │:8080 │──│    :8428     │◄─│      :3000       │               │
│ └──────┘  │  (scraper)   │  │  (dashboards)    │               │
│           │  (storage)   │  │                  │               │
│           │   50Gi NFS   │  │    5Gi NFS       │               │
│           └──────────────┘  └──────────────────┘                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Despliegue

### Opción 1: Con zcloud (recomendado)

```bash
# Aplicar en orden
zcloud apply 00-namespace.yaml
zcloud apply 01-node-exporter.yaml
zcloud apply 02-victoriametrics.yaml
zcloud apply 03-grafana.yaml
zcloud apply 04-kube-state-metrics.yaml

# O todo de una vez
for f in 0*.yaml; do zcloud apply $f; done
```

### Opción 2: Con kubectl directo

```bash
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-node-exporter.yaml
kubectl apply -f 02-victoriametrics.yaml
kubectl apply -f 03-grafana.yaml
kubectl apply -f 04-kube-state-metrics.yaml
```

## Verificar despliegue

```bash
# Ver pods
zcloud k get pods -n monitoring

# Output esperado:
# NAME                                  READY   STATUS    RESTARTS   AGE
# node-exporter-xxxxx                   1/1     Running   0          1m
# node-exporter-yyyyy                   1/1     Running   0          1m
# node-exporter-zzzzz                   1/1     Running   0          1m
# node-exporter-wwwww                   1/1     Running   0          1m
# victoriametrics-xxxxx                 1/1     Running   0          1m
# grafana-xxxxx                         1/1     Running   0          1m
# kube-state-metrics-xxxxx              1/1     Running   0          1m

# Ver PVCs
zcloud k get pvc -n monitoring

# Output esperado:
# NAME                   STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS
# victoriametrics-data   Bound    ...      50Gi       RWO            nfs-shared
# grafana-data           Bound    ...      5Gi        RWO            nfs-shared
```

## Acceso

### Port-forward temporal (para probar)

```bash
# Grafana
zcloud port-forward grafana.monitoring.svc 3000:3000
# Abrir http://localhost:3000

# VictoriaMetrics UI
zcloud port-forward victoriametrics.monitoring.svc 8428:8428
# Abrir http://localhost:8428/vmui
```

### Credenciales Grafana

| Usuario | Password |
|---------|----------|
| admin | zcloud-admin-2026 |

**⚠️ Cambiar la contraseña después del primer login**

## Dashboards incluidos

1. **ZCloud - Node Overview** (`zcloud-nodes`)
   - CPU usage por nodo
   - Memory usage por nodo
   - Disk usage (root)
   - Network I/O
   - Disk I/O
   - Node status (UP/DOWN)

2. **ZCloud - Kubernetes Cluster** (`zcloud-k8s`)
   - Total nodes/pods
   - Pods not running
   - CPU por namespace
   - Memory por namespace
   - Network I/O por namespace

## Métricas disponibles

### Node Exporter (por nodo)
- `node_cpu_seconds_total` - CPU
- `node_memory_*` - RAM
- `node_filesystem_*` - Disco
- `node_network_*` - Red
- `node_disk_*` - I/O disco
- `node_load*` - Load average

### Kube State Metrics (objetos K8s)
- `kube_pod_*` - Estado de pods
- `kube_deployment_*` - Deployments
- `kube_node_*` - Nodos
- `kube_pvc_*` - Volúmenes

### cAdvisor (contenedores)
- `container_cpu_*` - CPU por contenedor
- `container_memory_*` - Memory por contenedor
- `container_network_*` - Red por contenedor

## Retención de datos

- **VictoriaMetrics**: 90 días (configurable en `-retentionPeriod`)
- **Grafana**: Dashboards en ConfigMap (persistentes)

## Troubleshooting

### VictoriaMetrics no scrapea

```bash
# Ver targets
curl http://localhost:8428/targets

# Ver config
zcloud k logs -n monitoring deploy/victoriametrics
```

### Grafana no arranca

```bash
# Ver logs
zcloud k logs -n monitoring deploy/grafana

# Verificar permisos del PVC
zcloud k describe pvc grafana-data -n monitoring
```

### Node Exporter no aparece en nodo

```bash
# Verificar DaemonSet
zcloud k get ds -n monitoring

# Ver pods en todos los nodos
zcloud k get pods -n monitoring -o wide
```

## Próximos pasos

1. **Traefik Ingress** - Exponer Grafana en `grafana.zyrak.cloud`
2. **Alerting** - Configurar alertas en Grafana/Alertmanager
3. **Wazuh** - Security monitoring