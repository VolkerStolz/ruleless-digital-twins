from rdflib import Graph, URIRef
from rdflib.namespace import Namespace, OWL, XSD
from RDTBindings import *

g = Graph()
MINE = Namespace("http://www.semanticweb.org/vs/ontologies/2026/05/mh30#")
g.bind("", MINE)
g.bind("rdt", RDT)

g.add((URIRef(str(MINE)), OWL.imports, URIRef(str(RDT))))

temperature = ObservableProperty(g, MINE["T_Water"], None)
consumption = ObservableProperty(g, MINE["y_E_consumed_kWh"], None)

heaterChange = Change(g, MINE["WaterHeaterChange"], temperature, increase=True)
heaterPowerChange = Change(g, MINE["WaterPowerChange"], consumption, increase=True)
# Potential for RDT:Effect ->HERE<-.
heaterActuator = Actuator(g, MINE["WaterHeaterActuator"], [heaterChange, heaterPowerChange], actuatorName="u_enable",
                              actuatorType=XSD.boolean, actuatorStates=[False,True])

minTemp = Property(g, MINE["TemperatureLowerLimit"], 60)
maxTemp = Property(g, MINE["TemperatureUpperLimit"], 65)
oc_rtemp = OptimalConditionDouble(g, MINE["oc_temp"], temperature, minTemp, maxTemp)

tempSensor = Sensor(g, MINE["TempSensor"], [temperature,consumption])
tempMeasure = Measure(g, MINE["TempMeasure"])

tempProcedure = Procedure(g, MINE["TempProcedure"], tempMeasure, tempSensor)

room = Platform(g, MINE["MH30"], False, [heaterActuator, tempSensor], implements=[oc_rtemp])
fmu = FMU(g, MINE["Watertank_FMU"], "mh30_tank.fmu", 300)
room.addFMU(g, fmu)

output = g.serialize(destination=None)
print(output)
