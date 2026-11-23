#include <stdio.h>
#include <webots/robot.h>
#include <webots/supervisor.h>
int main(void) {
  wb_robot_init();
  WbNodeRef ball = wb_supervisor_node_get_from_def("BALL");
  WbFieldRef translation = wb_supervisor_node_get_field(ball, "translation");
  double initial = wb_supervisor_field_get_sf_vec3f(translation)[2];
  for (int i=0;i<60;i++) if (wb_robot_step(32)==-1) return 2;
  double final = wb_supervisor_field_get_sf_vec3f(translation)[2];
  double time = wb_robot_get_time();
  int pass = initial > 1.9 && final > 0.1 && final < 0.3 && time > 1.8;
  printf("WEBOTS_MIGRATION_%s initial=%.3f final=%.3f time=%.3f\n", pass ? "PASS" : "FAIL", initial, final, time);
  fflush(stdout);
  FILE *report = fopen("migration-result.txt", "w");
  if (report) { fprintf(report, "pass=%d initial=%f final=%f time=%f\n", pass, initial, final, time); fclose(report); }
  wb_supervisor_simulation_quit(pass ? 0 : 1);
  wb_robot_cleanup();
  return pass ? 0 : 1;
}
