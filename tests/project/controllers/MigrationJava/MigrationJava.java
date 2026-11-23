import com.cyberbotics.webots.controller.Supervisor;
import com.cyberbotics.webots.controller.Field;
import java.nio.file.*;
public class MigrationJava {
 public static void main(String[] args) throws Exception {
  Supervisor robot = new Supervisor();
  Field field = robot.getFromDef("BALL").getField("translation");
  double initial = field.getSFVec3f()[2];
  for (int i=0;i<60;i++) if (robot.step(32)==-1) throw new Exception("early termination");
  double end = field.getSFVec3f()[2];
  boolean ok = initial > 1.9 && end > 0.1 && end < 0.3 && robot.getTime() > 1.8;
  Files.writeString(Path.of("migration-result.txt"), "pass="+(ok?1:0)+" final="+end+" time="+robot.getTime()+"\n");
  robot.simulationQuit(ok ? 0 : 1);
 }
}
