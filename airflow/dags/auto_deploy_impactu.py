"""
DAG para auto-deployment de código impactu_airflow desde Git.

Este DAG monitorea el repositorio de impactu_airflow y cuando detecta cambios,
actualiza automáticamente el código en todos los contenedores sin necesidad de rebuild.
"""

from datetime import datetime, timedelta
import subprocess

from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.providers.standard.sensors.python import PythonSensor
from airflow.models import Variable


def check_for_updates(**context):
    """
    Verifica si hay una nueva versión del código en el repositorio Git.
    Compara el último commit hash con el almacenado en Variables.
    """
    import requests
    
    # URL de la API de GitHub para obtener el último commit
    repo_url = "https://api.github.com/repos/omazapa/impactu_airflow/commits/main"
    
    try:
        response = requests.get(repo_url, timeout=10)
        response.raise_for_status()
        latest_commit = response.json()["sha"]
        
        # Obtener el último commit conocido
        last_deployed_commit = Variable.get("impactu_last_deployed_commit", default_var=None)
        
        print(f"Latest commit in repo: {latest_commit}")
        print(f"Last deployed commit: {last_deployed_commit}")
        
        # Si hay un nuevo commit, retornar True
        if last_deployed_commit != latest_commit:
            print(f"🆕 New commit detected: {latest_commit}")
            # Guardar el nuevo commit para la próxima verificación
            context["ti"].xcom_push(key="new_commit", value=latest_commit)
            return True
        else:
            print("✅ No changes detected, already up to date")
            return False
            
    except Exception as e:
        print(f"❌ Error checking for updates: {e}")
        return False


def update_package_locally(**context):
    """
    Actualiza el paquete impactu_airflow localmente en el contenedor actual.
    Cada tarea se ejecuta en su propio worker/scheduler/dag-processor.
    """
    try:
        import sys
        
        # Ejecutar pip directamente en el proceso actual
        cmd = [
            sys.executable, "-m", "pip", "install", 
            "--upgrade", "--force-reinstall", "--no-cache-dir",
            "git+https://github.com/omazapa/impactu_airflow.git@main"
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=300  # 5 minutos timeout
        )
        
        if result.returncode == 0:
            print(f"✅ Successfully updated impactu_airflow package")
            print(result.stdout)
            return True
        else:
            print(f"❌ Failed to update package")
            print(result.stderr)
            raise Exception(f"Update failed: {result.stderr}")
            
    except subprocess.TimeoutExpired:
        raise Exception("Update timeout")
    except Exception as e:
        raise Exception(f"Error updating package: {str(e)}")


def save_deployed_commit(**context):
    """
    Guarda el commit hash que fue desplegado exitosamente.
    """
    ti = context["ti"]
    new_commit = ti.xcom_pull(task_ids="check_updates", key="new_commit")
    
    if new_commit:
        Variable.set("impactu_last_deployed_commit", new_commit)
        print(f"✅ Saved deployed commit: {new_commit}")
    else:
        print("⚠️ No new commit to save")


# Configuración del DAG
default_args = {
    "owner": "devops",
    "depends_on_past": False,
    "start_date": datetime(2025, 1, 1),
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="auto_deploy_impactu",
    default_args=default_args,
    description="Auto-deploy impactu_airflow code from Git when changes are detected",
    schedule="*/10 * * * *",  # Cada 10 minutos
    catchup=False,
    tags=["deployment", "automation", "impactu"],
) as dag:

    # Sensor que verifica si hay cambios
    check_updates = PythonSensor(
        task_id="check_updates",
        python_callable=check_for_updates,
        mode="poke",
        poke_interval=60,  # Verificar cada 60 segundos
        timeout=600,  # Timeout de 10 minutos
        soft_fail=False,
    )

    # Tarea que actualiza el paquete localmente
    # Se ejecutará en el worker que tome la tarea
    update_package = PythonOperator(
        task_id="update_package",
        python_callable=update_package_locally,
    )

    # Guardar el commit desplegado
    save_commit = PythonOperator(
        task_id="save_deployed_commit",
        python_callable=save_deployed_commit,
    )

    # Definir dependencias
    check_updates >> update_package >> save_commit
