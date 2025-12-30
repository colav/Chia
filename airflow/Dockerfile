ARG AIRFLOW_VERSION=3.1.5
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

# Copy DAGs and plugins to a base directory to be used by entrypoint if needed
COPY --chown=airflow:0 dags/ /opt/airflow/dags_base/
COPY --chown=airflow:0 plugins/ /opt/airflow/plugins_base/

# Set default environment to prod
ENV ENVIRONMENT=prod

COPY requirements.txt .
ARG PACKAGE_VERSION=latest
RUN if [ "$PACKAGE_VERSION" = "latest" ]; then \
        uv pip install --system --no-cache -r requirements.txt; \
    else \
        # Replace impactu-airflow with specific version if provided
        sed -i "s/impactu-airflow/impactu-airflow==$PACKAGE_VERSION/g" requirements.txt && \
        uv pip install --system --no-cache -r requirements.txt; \
    fi

USER airflow

# This is the base infrastructure image.
# It provides the Airflow version and system tools.
