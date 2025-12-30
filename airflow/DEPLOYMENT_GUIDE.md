# Guía de Despliegue - Airflow con Git Bundle

## Arquitectura de Despliegue

Esta configuración implementa una solución profesional que permite:
- ✅ Actualización automática de DAGs sin rebuild ni restart
- ✅ Actualización de código compartido en caliente
- ✅ Todo versionado desde Git (sin necesidad de PyPI)

## Componentes

### 1. Código Compartido (extract, load, transform)
- **Ubicación**: Repositorio `colav/impactu_airflow`
- **Instalación**: Desde Git en `requirements.txt`
- **Actualización**: Hot-reload sin rebuild

### 2. DAGs
- **Ubicación**: Repositorio `colav/impactu_airflow/dags/`
- **Despliegue**: Git Bundle (auto-refresh cada 5 minutos)
- **Actualización**: Automática sin intervención

## Configuración Inicial

### requirements.txt
```txt
apache-airflow-providers-mongo==5.3.0
apache-airflow-providers-git==1.0.1
pymongo==4.15.5
pandas==2.1.4
requests==2.32.5

# Instalar impactu_airflow desde PyPI
impactu-airflow
```

### docker-compose.yaml
```yaml
AIRFLOW__DAG_PROCESSOR__DAG_BUNDLE_CONFIG_LIST: |
  [
      {
          "name": "impactu_prod",
          "classpath": "airflow.providers.git.bundles.git.GitDagBundle",
          "kwargs": {
              "git_conn_id": "git_impactu",
              "tracking_ref": "main",
              "refresh_interval": 300,
              "subdir": "."
          }
      }
  ]
```

### Estructura de imports en DAGs
```python
# dags/extract_scimagojr.py
from impactu_airflow.extract.scimagojr import ScimagoJRExtractor  # Desde paquete instalado
```

## Flujos de Actualización

### Actualizar DAGs (Automático)

```bash
# 1. Modificar DAGs en el repositorio
cd impactu_airflow
vim dags/extract_scimagojr.py

# 2. Commit y push
git add .
git commit -m "Update DAG"
git push origin main

# 3. Esperar 5 minutos
# Airflow detecta automáticamente los cambios y recarga los DAGs
# ✅ Sin rebuild, sin restart, sin intervención manual
```

### Actualizar Código Compartido (Hot-reload)

```bash
# 1. Actualizar en caliente en todos los contenedores desde PyPI
docker exec airflow-prod-airflow-worker-1 pip install --upgrade impactu-airflow

docker exec airflow-prod-airflow-dag-processor-1 pip install --upgrade impactu-airflow

docker exec airflow-prod-airflow-scheduler-1 pip install --upgrade impactu-airflow

# ✅ Sin rebuild, sin restart de Airflow
```

### Script de actualización automatizado

Puedes crear un script para simplificar:

```bash
# update_impactu_code.sh
#!/bin/bash
set -e

echo "🔄 Actualizando código impactu_airflow desde PyPI..."

CONTAINERS=(
    "airflow-prod-airflow-worker-1"
    "airflow-prod-airflow-dag-processor-1"
    "airflow-prod-airflow-scheduler-1"
)

for container in "${CONTAINERS[@]}"; do
    echo "📦 Actualizando $container..."
    docker exec $container pip install --upgrade impactu-airflow
done

echo "✅ Actualización completada en todos los contenedores"
```

Uso:
```bash
chmod +x update_impactu_code.sh
./update_impactu_code.sh
```

## Ventajas de esta Arquitectura

| Aspecto | Solución | Beneficio |
|---------|----------|-----------|
| **DAGs** | Git Bundle con auto-refresh | Se actualizan solos cada 5 min |
| **Código compartido** | Instalado desde PyPI | Hot-reload sin rebuild |
| **Versioning** | PyPI / Git | Trazabilidad completa |
| **Deploy time** | < 1 minuto | Solo comandos pip |
| **Rollback** | Git revert + update | Inmediato |
| **CI/CD** | Git push automático | Sin intervención manual |

## Troubleshooting

### DAGs no se actualizan
```bash
# Verificar el bundle está configurado
docker exec airflow-prod-airflow-dag-processor-1 \
  ls -la /tmp/airflow/dag_bundles/impactu_prod/tracking_repo/

# Forzar refresh manual (solo para debug)
docker restart airflow-prod-airflow-dag-processor-1
```

### Imports fallan después de actualizar código
```bash
# Verificar el paquete está instalado correctamente
docker exec airflow-prod-airflow-worker-1 pip show impactu-airflow

# Reinstalar si es necesario
./update_impactu_code.sh
```

### Ver logs del Git Bundle
```bash
docker logs airflow-prod-airflow-dag-processor-1 | grep -i "bundle\|impactu"
```

## Notas Importantes

1. **Refresh interval**: Configurado a 300 segundos (5 minutos). Para cambiar:
   ```yaml
   "refresh_interval": 60  # 1 minuto
   ```

2. **Branch tracking**: Actualmente apunta a `main`. Para usar otra rama:
   ```yaml
   "tracking_ref": "develop"
   ```

3. **Subdir**: Configurado como `"."` para incluir todo el repositorio. Para solo DAGs:
   ```yaml
   "subdir": "dags"
   ```

4. **Primera instalación**: Requiere rebuild inicial:
   ```bash
   ./manage.sh prod build
   ./manage.sh prod up -d
   ```

5. **Actualizaciones posteriores**: Sin rebuild ni restart, solo hot-reload.
