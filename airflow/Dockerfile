ARG AIRFLOW_VERSION=3.1.0
FROM apache/airflow:${AIRFLOW_VERSION}-python3.12

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Copy DAGs and plugins to the image
COPY --chown=airflow:0 dags/ /opt/airflow/dags/
COPY --chown=airflow:0 plugins/ /opt/airflow/plugins/

# Set default environment to prod
ENV ENVIRONMENT=prod

USER airflow

# This is the base infrastructure image.
# It provides the Airflow version and system tools.
