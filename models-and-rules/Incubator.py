from rdflib import Graph, URIRef
from rdflib.namespace import Namespace, OWL, XSD
from RDTBindings import *

g = Graph()
MINE = Namespace("http://www.semanticweb.org/vs/ontologies/2025/12/incubator#")
g.bind("", MINE)
g.bind("rdt", RDT)

g.add((URIRef(str(MINE)), OWL.imports, URIRef(str(RDT))))

temperature = ObservableProperty(g, MINE["T"], None)
power = ObservableProperty(g, MINE["total_power_box"], None)

heaterChange = Change(g, MINE["HeaterChange"], temperature, increase=True)
# Potential for RDT:Effect ->HERE<-.
heaterActuator = Actuator(g, MINE["HeaterActuator"], heaterChange, actuatorName="in_heater_state",
                              actuatorType=XSD.integer, actuatorStates=[0,1])

fan = Actuator(g, MINE["FanActuator"], None, # Pin fan to "on"
                    actuatorType=XSD.integer, actuatorStates=[1])

rtemp = ObservableProperty(g, MINE["in_room_temperature"], Literal("21.0", datatype=XSD.double))
#rtempActuator = Actuator(g, MINE["TempActuator"], Change(g, MINE["TempChange"], rtemp), isParameter=True,
#                             actuatorName="in_room_temperature", actuatorType=XSD.double, actuatorStates=[21.0])

minTemp = Property(g, MINE["TemperatureLowerLimit"], 30)
maxTemp = Property(g, MINE["TemperatureUpperLimit"], 35)
oc_rtemp = OptimalConditionDouble(g, MINE["oc_temp"], temperature, minTemp, maxTemp)

# Piggy-back power onto here. TODO: Call it `boxSensor` maybe?
tempSensor = Sensor(g, MINE["TempSensor"], [temperature, power])
tempMeasure = Measure(g, MINE["TempMeasure"])

tempProcedure = Procedure(g, MINE["TempProcedure"], tempMeasure, tempSensor)

room = Platform(g, MINE["IncubatorTest"], False, [heaterActuator, tempSensor, fan], implements=[oc_rtemp])
fmu = FMU(g, MINE["Incubator_FMU"], "au_incubator.fmu", 3) # 3s
room.addFMU(g, fmu)
# Minimize energy consumption by using temperature as a proxy.
# Should make controller deterministic while within OC-range instead of wobbling around.
g.add((room.node, RDT["minimizes"], temperature.node))
# g.add((room.node, RDT["minimizes"], power.node))

output = g.serialize(destination=None)
print(output)
