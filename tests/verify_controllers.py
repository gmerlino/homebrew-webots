#!/usr/bin/env python3
"""Compile and run C, C++, Python and Java controllers against a supplied Webots bundle."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
args = parser.parse_args()
app = args.app.resolve()
with tempfile.TemporaryDirectory(prefix='webots-controllers-') as temporary:
    root = Path(temporary)
    project = root / 'project'
    shutil.copytree(Path(__file__).parent / 'project', project)
    env = dict(os.environ, WEBOTS_HOME=str(app), WEBOTS_HOME_PATH=str(app/'Contents'), NO_FAT_BINARY='1', PROCESSOR='arm64')
    env.pop('PKG_CONFIG_PATH', None)
    env.pop('CMAKE_PREFIX_PATH', None)
    for name in ('migration_test', 'migration_cpp'):
        subprocess.run(['make'], cwd=project/'controllers'/name, env=env, check=True, timeout=60)
    subprocess.run(['javac', '--release', '11', '-cp', str(app/'Contents/lib/controller/java/Controller.jar'),
                    str(project/'controllers/MigrationJava/MigrationJava.java')], env=env, check=True, timeout=60)
    for name, world in [('migration_test','migration'), ('migration_cpp','migration_cpp'),
                        ('migration_python','migration_python'), ('MigrationJava','MigrationJava')]:
        completed = subprocess.run([str(app/'Contents/MacOS/webots'), '--batch', '--mode=fast',
                                    '--no-rendering', '--stdout', '--stderr', str(project/'worlds'/f'{world}.wbt')],
                                   env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90)
        report = project/'controllers'/name/'migration-result.txt'
        if completed.returncode or not report.exists() or not report.read_text().startswith('pass=1 '):
            raise RuntimeError(f'{name} failed ({completed.returncode}):\n{completed.stdout}')
        print(name, report.read_text().strip(), flush=True)
