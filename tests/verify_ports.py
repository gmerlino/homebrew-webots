#!/usr/bin/env python3
"""Verify that Webots avoids an occupied controller port on macOS."""
import argparse
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('app', type=Path)
args = parser.parse_args()
with socket.socket() as occupied, tempfile.TemporaryDirectory(prefix='webots-port-') as temporary:
    occupied.bind(('127.0.0.1', 0))
    occupied.listen(1)
    port = occupied.getsockname()[1]
    root = Path(temporary)
    world = root/'worlds/visual.wbt'
    world.parent.mkdir()
    shutil.copy2(Path(__file__).parent/'project/worlds/visual.wbt', world)
    with (root/'webots.log').open('w') as log:
        process = subprocess.Popen([str(args.app.resolve()/'Contents/MacOS/webots'), '--batch', '--mode=pause',
                                    f'--port={port}', str(world)], stdout=log, stderr=subprocess.STDOUT)
        try:
            for _ in range(60):
                result = subprocess.run(['/usr/sbin/lsof', '-nP', '-a', '-p', str(process.pid),
                                         '-iTCP', '-sTCP:LISTEN'], text=True, capture_output=True, check=False)
                if any(f':{candidate} ' in result.stdout for candidate in range(port+1, min(port+11,65536))):
                    print(f'PASS: occupied port {port} skipped; Webots opened a subsequent port')
                    break
                if process.poll() is not None:
                    raise RuntimeError('Webots exited before opening its server')
                time.sleep(0.5)
            else:
                raise RuntimeError('Expected listening socket not found: '+result.stdout)
        finally:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
