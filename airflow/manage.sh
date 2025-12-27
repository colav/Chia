#!/bin/bash

# Script para gestionar las instancias de Airflow (Dev/Prod)
# Uso: ./manage.sh [dev|prod] [up|down|restart|logs|pull|ps|build|push]

ENV=$1
ACTION=${2:-up}

# Validar entorno
if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
    echo "❌ Error: Debes especificar el entorno (dev o prod)."
    echo "Uso: $0 [dev|prod] [up|down|restart|logs|pull|ps]"
    exit 1
fi

PROJECT_NAME="airflow-$ENV"
ENV_FILE=".env.$ENV"

# Verificar que el archivo .env existe
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ Error: No se encuentra el archivo $ENV_FILE"
    exit 1
fi

echo "🚀 Ejecutando '$ACTION' en el entorno '$ENV' (Proyecto: $PROJECT_NAME)..."

case $ACTION in
    up)
        docker compose -p "$PROJECT_NAME" --env-file "$ENV_FILE" up -d
        ;;
    down)
        docker compose -p "$PROJECT_NAME" --env-file "$ENV_FILE" down
        ;;
    logs)
        docker compose -p "$PROJECT_NAME" --env-file "$ENV_FILE" logs -f --tail 100
        ;;
    build)
        # Obtener el tag del archivo .env
        TAG=$(grep AIRFLOW_IMAGE_TAG "$ENV_FILE" | cut -d'=' -f2)
        TAG=${TAG:-latest}
        echo "🛠 Construyendo imagen localmente con tag: colav/impactu_airflow:$TAG"
        docker build -t "colav/impactu_airflow:$TAG" ../../impactu_airflow
        ;;
    push)
        # Obtener el tag del archivo .env
        TAG=$(grep AIRFLOW_IMAGE_TAG "$ENV_FILE" | cut -d'=' -f2)
        TAG=${TAG:-latest}
        echo "📤 Subiendo imagen a Docker Hub: colav/impactu_airflow:$TAG"
        docker push "colav/impactu_airflow:$TAG"
        ;;
    *)
        docker compose -p "$PROJECT_NAME" --env-file "$ENV_FILE" $ACTION
        ;;
esac
