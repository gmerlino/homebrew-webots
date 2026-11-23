#include <webots/Supervisor.hpp>
#include <webots/Node.hpp>
#include <webots/Field.hpp>
#include <fstream>
int main(){webots::Supervisor robot;auto f=robot.getFromDef("BALL")->getField("translation");double initial=f->getSFVec3f()[2];for(int i=0;i<60;i++)if(robot.step(32)==-1)return 2;double end=f->getSFVec3f()[2];bool ok=initial>1.9&&end>0.1&&end<0.3&&robot.getTime()>1.8;{std::ofstream out("migration-result.txt");out<<"pass="<<ok<<" final="<<end<<" time="<<robot.getTime()<<"\n";}robot.simulationQuit(ok?0:1);return ok?0:1;}
