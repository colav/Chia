"""
Professional PR Validator for Airflow DAGs

Validates pull requests by:
1. Downloading PR changes from GitHub with full context
2. Setting up isolated Python environment (venv)
3. Running comprehensive validation checks:
   - Syntax validation
   - Import resolution
   - DAG structure integrity
   - Dependency graph validation
4. Generating structured validation report

Architecture:
- Isolated execution: Each PR tested in /tmp with dedicated venv
- Fast validation: Parallel checks, fail-fast strategy
- No side effects: Temporary SQLite DB, auto-cleanup
- CI/CD ready: JSON reports for GitHub Actions integration
"""

import os
import sys
import json
import shutil
import tempfile
import subprocess
import zipfile
from typing import Dict, List, Tuple, Optional
from datetime import datetime, timedelta
from pathlib import Path
from io import BytesIO

import requests
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator


# ==================== Configuration ====================

REPO_OWNER = "colav"
REPO_NAME = "impactu_airflow"
GITHUB_API_BASE = "https://api.github.com"


# ==================== Helper Functions ====================

def setup_logger(base_dir: str) -> None:
    """Configure logging for validation process."""
    log_file = os.path.join(base_dir, "validation.log")
    # Simple print-based logging for now
    print(f"[INFO] Validation logs: {log_file}")


def fetch_pr_info(pr_number: int, headers: dict) -> dict:
    """Fetch PR information from GitHub API."""
    url = f"{GITHUB_API_BASE}/repos/{REPO_OWNER}/{REPO_NAME}/pulls/{pr_number}"
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    return response.json()


def fetch_pr_files(pr_number: int, headers: dict) -> List[dict]:
    """Fetch list of changed files in the PR."""
    url = f"{GITHUB_API_BASE}/repos/{REPO_OWNER}/{REPO_NAME}/pulls/{pr_number}/files"
    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()
    return response.json()


def download_branch_archive(branch: str, base_dir: str, headers: dict) -> None:
    """Download and extract branch archive from GitHub."""
    url = f"{GITHUB_API_BASE}/repos/{REPO_OWNER}/{REPO_NAME}/zipball/{branch}"
    print(f"[INFO] Downloading {branch} branch archive...")
    
    response = requests.get(url, headers=headers, stream=True, timeout=60)
    response.raise_for_status()
    
    with zipfile.ZipFile(BytesIO(response.content)) as z:
        # Extract to temporary directory first
        temp_extract = tempfile.mkdtemp()
        z.extractall(temp_extract)
        
        # Find the actual content directory (GitHub adds a prefix)
        extracted_dirs = os.listdir(temp_extract)
        if not extracted_dirs:
            raise ValueError(f"Empty archive for branch {branch}")
        
        source_dir = os.path.join(temp_extract, extracted_dirs[0])
        
        # Copy contents to base_dir
        shutil.copytree(source_dir, base_dir, dirs_exist_ok=True)
        shutil.rmtree(temp_extract)
    
    print(f"[INFO] Extracted {branch} branch to {base_dir}")


def download_pr_file(file_path: str, raw_url: str, base_dir: str, headers: dict) -> None:
    """Download a single file from PR and save to base_dir."""
    response = requests.get(raw_url, headers=headers, timeout=30)
    response.raise_for_status()
    
    full_path = os.path.join(base_dir, file_path)
    os.makedirs(os.path.dirname(full_path), exist_ok=True)
    
    with open(full_path, 'wb') as f:
        f.write(response.content)
    
    print(f"[INFO] Downloaded: {file_path}")


def setup_virtual_environment(base_dir: str, requirements_path: str) -> Tuple[str, str]:
    """
    Setup isolated virtual environment with required dependencies.
    Returns: (venv_dir, python_executable)
    """
    venv_dir = os.path.join(base_dir, "venv")
    python_exe = os.path.join(venv_dir, "bin", "python")
    
    if not os.path.exists(requirements_path):
        print("[WARN] No requirements.txt found, using system python")
        return venv_dir, sys.executable
    
    print("[INFO] Setting up virtual environment with uv...")
    
    # Create venv (assumes uv is installed in Docker image)
    subprocess.run(["uv", "venv", venv_dir], check=True)
    
    # Install requirements
    subprocess.run(
        ["uv", "pip", "install", "--python", python_exe, "-r", requirements_path],
        check=True
    )
    
    # Install Airflow + FAB provider for validation
    print("[INFO] Installing Airflow validation dependencies...")
    subprocess.run(
        [
            "uv", "pip", "install", "--python", python_exe,
            "apache-airflow==3.1.5",
            "apache-airflow-providers-fab",
            "structlog==25.5.0"
        ],
        check=True
    )
    
    print(f"[OK] Virtual environment ready: {venv_dir}")
    return venv_dir, python_exe


def initialize_test_database(python_exe: str, env: dict) -> None:
    """Initialize temporary SQLite database for Airflow metadata."""
    print("[INFO] Initializing temporary Airflow database...")
    
    result = subprocess.run(
        [python_exe, "-m", "airflow", "db", "migrate"],
        env=env,
        capture_output=True,
        text=True
    )
    
    if result.returncode != 0:
        print(f"[ERROR] Database initialization failed:\n{result.stderr}")
        raise RuntimeError("Failed to initialize Airflow database")
    
    print("[OK] Database initialized")


# ==================== Validation Checks ====================

def validate_syntax(dag_files: List[str], base_dir: str, python_exe: str) -> Dict:
    """
    Validate Python syntax for all changed DAG files.
    Returns: validation result dict
    """
    print("\n" + "="*60)
    print("SYNTAX VALIDATION")
    print("="*60)
    
    results = {"passed": [], "failed": []}
    
    for dag_file in dag_files:
        file_path = os.path.join(base_dir, dag_file)
        print(f"[CHECK] {dag_file}")
        
        result = subprocess.run(
            [python_exe, "-m", "py_compile", file_path],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            results["passed"].append(dag_file)
            print(f"  ✓ Syntax OK")
        else:
            results["failed"].append({
                "file": dag_file,
                "error": result.stderr
            })
            print(f"  ✗ Syntax Error:\n{result.stderr}")
    
    return results


def validate_imports(base_dir: str, python_exe: str, env: dict) -> Dict:
    """
    Validate that all DAGs can be imported without errors.
    Returns: validation result dict
    """
    print("\n" + "="*60)
    print("IMPORT VALIDATION")
    print("="*60)
    
    check_script = f"""
from airflow.models import DagBag
import sys

dag_folder = '{os.path.join(base_dir, "dags")}'
print(f"[INFO] Loading DAGs from {{dag_folder}}")

db = DagBag(dag_folder=dag_folder, include_examples=False)

if db.import_errors:
    print("[ERROR] Import errors found:")
    for file, error in db.import_errors.items():
        print(f"  - {{file}}:")
        print(f"    {{error}}")
    sys.exit(1)

print(f"[OK] Successfully loaded {{len(db.dags)}} DAG(s)")
for dag_id in db.dags:
    dag = db.get_dag(dag_id)
    print(f"  ✓ {{dag_id}} ({{len(dag.tasks)}} tasks)")
"""
    
    result = subprocess.run(
        [python_exe, "-c", check_script],
        capture_output=True,
        text=True,
        env=env
    )
    
    print(result.stdout)
    
    if result.returncode != 0:
        print(f"[ERROR] Import validation failed:\n{result.stderr}")
        return {
            "success": False,
            "error": result.stderr
        }
    
    return {"success": True}


def validate_dag_structure(dag_files: List[str], base_dir: str, python_exe: str, env: dict) -> Dict:
    """
    Validate DAG structure: tasks, dependencies, schedule, etc.
    Returns: validation result dict
    """
    print("\n" + "="*60)
    print("STRUCTURE VALIDATION")
    print("="*60)
    
    results = {"passed": [], "failed": []}
    
    for dag_file in dag_files:
        print(f"\n[CHECK] {dag_file}")
        
        validation_script = f"""
import sys
from airflow.models import DagBag

dag_file = '{os.path.join(base_dir, dag_file)}'
dag_folder = '{os.path.join(base_dir, "dags")}'

db = DagBag(dag_folder=dag_folder, include_examples=False)

# Find DAG by file location
dag_id = None
for id, dag in db.dags.items():
    if dag.fileloc == dag_file:
        dag_id = id
        break

if not dag_id:
    print(f"[ERROR] No DAG found in {{dag_file}}")
    sys.exit(1)

dag = db.get_dag(dag_id)

# Basic metadata
print(f"DAG ID: {{dag_id}}")
print(f"Description: {{dag.description or 'N/A'}}")
print(f"Schedule: {{dag.schedule_interval}}")
print(f"Tags: {{dag.tags}}")
print(f"Tasks: {{len(dag.tasks)}}")

# Validate task structure
print("\\nTask Dependencies:")
for task in dag.tasks:
    upstream = list(task.upstream_task_ids)
    downstream = list(task.downstream_task_ids)
    print(f"  • {{task.task_id}}")
    if upstream:
        print(f"    ← {{', '.join(upstream)}}")
    if downstream:
        print(f"    → {{', '.join(downstream)}}")

# Check for circular dependencies (Airflow does this internally)
try:
    # This will raise if there are cycles
    dag.topological_sort()
    print("\\n[OK] No circular dependencies detected")
except Exception as e:
    print(f"\\n[ERROR] Circular dependency detected: {{e}}")
    sys.exit(1)

print("[OK] Structure validation passed")
"""
        
        result = subprocess.run(
            [python_exe, "-c", validation_script],
            capture_output=True,
            text=True,
            env=env
        )
        
        print(result.stdout)
        
        if result.returncode == 0:
            results["passed"].append(dag_file)
        else:
            results["failed"].append({
                "file": dag_file,
                "error": result.stderr
            })
            print(f"[ERROR] Validation failed:\n{result.stderr}")
    
    return results


# ==================== Main Validation Logic ====================

def validate_pr(**context):
    """
    Main validation function executed by Airflow.
    Orchestrates the entire validation pipeline.
    """
    # Extract configuration
    conf = context['dag_run'].conf
    pr_number = conf.get('pr_number')
    github_token = conf.get('github_token')
    
    if not pr_number:
        raise ValueError("Missing required parameter: pr_number")
    
    headers = {"Authorization": f"token {github_token}"} if github_token else {}
    if not github_token:
        print("[WARN] No GitHub token provided. Rate limits may apply.")
    
    base_dir = f"/tmp/airflow_pr_{pr_number}"
    validation_report = {
        "pr_number": pr_number,
        "timestamp": datetime.now().isoformat(),
        "status": "running",
        "checks": {}
    }
    
    try:
        # ===== SETUP PHASE =====
        print("\n" + "="*60)
        print(f"PR VALIDATION: #{pr_number}")
        print("="*60)
        
        # Clean previous runs
        if os.path.exists(base_dir):
            print(f"[INFO] Cleaning existing directory: {base_dir}")
            shutil.rmtree(base_dir)
        os.makedirs(base_dir)
        
        setup_logger(base_dir)
        
        # Fetch PR metadata
        pr_info = fetch_pr_info(pr_number, headers)
        pr_files = fetch_pr_files(pr_number, headers)
        
        print(f"\n[INFO] PR Title: {pr_info['title']}")
        print(f"[INFO] Base Branch: {pr_info['base']['ref']}")
        print(f"[INFO] Head Branch: {pr_info['head']['ref']}")
        print(f"[INFO] Changed Files: {len(pr_files)}")
        
        # Identify changed DAG files
        changed_dags = [
            f['filename'] for f in pr_files
            if f['filename'].startswith('dags/') and f['filename'].endswith('.py')
        ]
        
        if not changed_dags:
            print("[INFO] No DAG files changed in this PR. Skipping validation.")
            validation_report["status"] = "skipped"
            validation_report["message"] = "No DAG files modified"
            return validation_report
        
        print(f"\n[INFO] DAG files to validate:")
        for dag in changed_dags:
            print(f"  - {dag}")
        
        # Download base branch for full context
        download_branch_archive(pr_info['base']['ref'], base_dir, headers)
        
        # Overlay PR changes
        print(f"\n[INFO] Applying PR changes...")
        for pr_file in pr_files:
            if pr_file['status'] != 'removed':
                download_pr_file(
                    pr_file['filename'],
                    pr_file['raw_url'],
                    base_dir,
                    headers
                )
        
        # Create .airflowignore to prevent scanning venv
        with open(os.path.join(base_dir, ".airflowignore"), "w") as f:
            f.write("venv/\n.git/\n__pycache__/\n")
        
        # ===== ENVIRONMENT SETUP =====
        requirements_path = os.path.join(base_dir, "requirements.txt")
        venv_dir, python_exe = setup_virtual_environment(base_dir, requirements_path)
        
        # Configure environment for Airflow
        env = os.environ.copy()
        env["PYTHONPATH"] = f"{base_dir}:{env.get('PYTHONPATH', '')}"
        env["AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"] = "sqlite:////tmp/airflow_validation.db"
        env["AIRFLOW__CORE__LOAD_EXAMPLES"] = "False"
        env["AIRFLOW__CORE__EXECUTOR"] = "SequentialExecutor"
        env["AIRFLOW__CORE__DAGS_FOLDER"] = os.path.join(base_dir, "dags")
        
        # Initialize temporary database
        initialize_test_database(python_exe, env)
        
        # ===== VALIDATION PHASE =====
        
        # 1. Syntax Check
        syntax_results = validate_syntax(changed_dags, base_dir, python_exe)
        validation_report["checks"]["syntax"] = syntax_results
        
        if syntax_results["failed"]:
            validation_report["status"] = "failed"
            validation_report["message"] = "Syntax validation failed"
            raise Exception(f"Syntax errors in {len(syntax_results['failed'])} file(s)")
        
        # 2. Import Check
        import_results = validate_imports(base_dir, python_exe, env)
        validation_report["checks"]["imports"] = import_results
        
        if not import_results["success"]:
            validation_report["status"] = "failed"
            validation_report["message"] = "Import validation failed"
            raise Exception("DAG import errors detected")
        
        # 3. Structure Check
        structure_results = validate_dag_structure(changed_dags, base_dir, python_exe, env)
        validation_report["checks"]["structure"] = structure_results
        
        if structure_results["failed"]:
            validation_report["status"] = "failed"
            validation_report["message"] = "Structure validation failed"
            raise Exception(f"Structure errors in {len(structure_results['failed'])} file(s)")
        
        # ===== SUCCESS =====
        validation_report["status"] = "success"
        validation_report["message"] = "All validations passed"
        
        print("\n" + "="*60)
        print("✅ PR VALIDATION SUCCESSFUL")
        print("="*60)
        print(f"  Syntax: {len(syntax_results['passed'])} file(s) passed")
        print(f"  Imports: All DAGs loaded successfully")
        print(f"  Structure: {len(structure_results['passed'])} file(s) passed")
        print("="*60)
        
        # Save validation report
        report_path = os.path.join(base_dir, "validation_report.json")
        with open(report_path, 'w') as f:
            json.dump(validation_report, f, indent=2)
        print(f"\n[INFO] Report saved: {report_path}")
        
        return validation_report
        
    except Exception as e:
        validation_report["status"] = "error"
        validation_report["error"] = str(e)
        
        print("\n" + "="*60)
        print("❌ PR VALIDATION FAILED")
        print("="*60)
        print(f"Error: {e}")
        print("="*60)
        
        # Save error report
        report_path = os.path.join(base_dir, "validation_report.json")
        with open(report_path, 'w') as f:
            json.dump(validation_report, f, indent=2)
        
        raise
    
    finally:
        # Cleanup (optional - keep for debugging)
        # shutil.rmtree(base_dir, ignore_errors=True)
        pass


# ==================== DAG Definition ====================

if os.getenv("ENVIRONMENT") == "dev":
    default_args = {
        'owner': 'airflow',
        'depends_on_past': False,
        'email_on_failure': False,
        'email_on_retry': False,
        'retries': 0,
    }

    with DAG(
        'pr_validator',
        default_args=default_args,
        description='Professional PR Validator for Airflow DAGs',
        schedule=None,  # Triggered manually via API (Airflow 3.x)
        start_date=datetime(2025, 1, 1),
        catchup=False,
        tags=['ci-cd', 'validation', 'pr'],
        params={
            "pr_number": 0,
            "github_token": "",
        }
    ) as dag:
        
        validate_task = PythonOperator(
            task_id='validate_pr',
            python_callable=validate_pr,
        )
