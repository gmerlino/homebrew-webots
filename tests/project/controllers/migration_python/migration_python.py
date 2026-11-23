from controller import Supervisor
from pathlib import Path
robot = Supervisor()
field = robot.getFromDef("BALL").getField("translation")
initial = field.getSFVec3f()[2]
for _ in range(60):
    if robot.step(32) == -1:
        raise RuntimeError("simulation ended early")
final = field.getSFVec3f()[2]
ok = initial > 1.9 and 0.1 < final < 0.3 and robot.getTime() > 1.8
Path("migration-result.txt").write_text(f"pass={int(ok)} initial={initial} final={final} time={robot.getTime()}\n")
robot.simulationQuit(0 if ok else 1)
