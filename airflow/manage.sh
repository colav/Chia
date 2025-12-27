#!/bin/bash

# Script para gestionar las instancias de Airflow (Dev/Prod)
# Uso: ./manage.sh [dev|prod] [up|down|restart|logs|pull|ps]

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
    *)
        docker compose -p "$PROJECT_NAME" --env-file "$ENV_FILE" $ACTION
        ;;
esac
