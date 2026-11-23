#!/usr/bin/env python3
"""Run the bundled vacuum gripper cycle, including its installed PROTO assets."""
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
with tempfile.TemporaryDirectory(prefix='webots-vacuum-') as temporary:
    project = Path(temporary)
    sample = app/'Contents/projects/samples/devices'
    controller = project/'controllers/vacuum_gripper'
    shutil.copytree(sample/'controllers/vacuum_gripper', controller)
    (project/'worlds').mkdir()
    world = project/'worlds/vacuum_gripper.wbt'
    world.write_text((sample/'worlds/vacuum_gripper.wbt').read_text().replace(
        'DEF ROBOT Robot {', 'DEF ROBOT Robot {\n  supervisor TRUE'))
    source = controller/'vacuum_gripper.c'
    code = source.read_text().replace('#include <webots/robot.h>', '#include <webots/robot.h>\n#include <webots/supervisor.h>')
    code = code.replace('bool connected = false;', 'bool connected = false;\n  bool picked = false;')
    code = code.replace('connected = wb_vacuum_gripper_get_presence(vacuum_gripper);',
                        'connected = wb_vacuum_gripper_get_presence(vacuum_gripper);\n      picked |= connected;')
    code = code.replace('wb_vacuum_gripper_disable_presence(vacuum_gripper);', '''int passed = picked && !wb_vacuum_gripper_is_on(vacuum_gripper);
  FILE *result = fopen("vacuum-result.txt", "w");
  fprintf(result, "pass=%d time=%f\\n", passed, wb_robot_get_time());
  fclose(result);
  wb_supervisor_simulation_quit(passed ? 0 : 1);
  wb_vacuum_gripper_disable_presence(vacuum_gripper);''')
    source.write_text(code)
    env = dict(os.environ, WEBOTS_HOME=str(app), WEBOTS_HOME_PATH=str(app/'Contents'), NO_FAT_BINARY='1', PROCESSOR='arm64')
    subprocess.run(['make', 'clean'], cwd=controller, env=env, check=True, capture_output=True)
    subprocess.run(['make'], cwd=controller, env=env, check=True, capture_output=True)
    run = subprocess.run([str(app/'Contents/MacOS/webots'), '--batch', '--mode=fast', '--stdout', '--stderr', str(world)],
                         env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
    report = controller/'vacuum-result.txt'
    if run.returncode or 'ERROR:' in run.stdout or not report.exists() or not report.read_text().startswith('pass=1 '):
        raise RuntimeError(f'Vacuum gripper failed ({run.returncode}):\n{run.stdout}')
    print('PASS: installed PROTO assets, gripper pickup and release:', report.read_text().strip())
