model WarmWaterTank
  "200-litre warm-water storage tank with 2000 W heating element.
   Heater cuts out at 65 °C (5 K hysteresis back to 60 °C).
   Insulation representative of state-of-the-art domestic hot-water
   cylinders circa 2015 (PUR foam ~50 mm, U_total ≈ 0.41 W/(m²·K)).

   FMI interface
   -------------
   Inputs:
     u_enable   – Boolean  – enables/disables the heater entirely
     T_water  – Real [°C] – current measured water temperature
                              (driven by the master; the internal ODE
                               state T is still integrated for
                               stand-alone use but the thermostat
                               logic uses T_water when the FMU
                               is coupled)
   Outputs:
     y_heater_on      – Boolean  – true when element is energised
     y_P_actual       – Real [W] – instantaneous electrical power
     y_E_consumed     – Real [J] – cumulative electrical energy
     y_E_consumed_kWh – Real [kWh] – same, in kWh
     
    $ fmpy --output-interval 900 simulate --stop-time 1200000 --output-file foo.csv --start-values u_enable true \\
           --output-variables T_water y_E_consumed_kWh y_heater_on -- mh30_tank.fmu"

  // ---------------------------------------------------------------
  //  FMI INPUTS
  // ---------------------------------------------------------------
  input Boolean u_enable;

  Real T_water(unit = "degC");

  // ---------------------------------------------------------------
  //  FMI OUTPUTS
  // ---------------------------------------------------------------
  Boolean y_heater_on;

  Real y_P_actual(unit = "W");

  Real y_E_consumed(unit = "J");

  Real y_E_consumed_kWh(unit = "kWh");

  // ---------------------------------------------------------------
  //  Physical constants
  // ---------------------------------------------------------------
  constant Real cp_water  = 4186  "Specific heat capacity of water  [J/(kg·K)]";
  constant Real rho_water = 985   "Density of water at ~55 °C  [kg/m³]";

  // ---------------------------------------------------------------
  //  Tank geometry & thermal mass
  // ---------------------------------------------------------------
  parameter Real V_tank   = 0.200
    "Tank volume  [m³]  (200 litres)";
  parameter Real m_water  = rho_water * V_tank
    "Mass of water  [kg]";

  // Vertical cylinder, height ≈ 2 × diameter:
  //   V = π/4 · d² · h = π/4 · d² · 2d  →  d ≈ 0.48 m, h ≈ 1.10 m
  //   A = π·d·h + 2·π/4·d² ≈ 1.87 m²
  parameter Real A_surface = 1.87
    "Tank outer surface area  [m²]";

  // ---------------------------------------------------------------
  //  Insulation – state of the art ~2015
  //  50 mm high-density PUR foam, λ ≈ 0.022 W/(m·K)
  //  R_foam = 0.050 / 0.022 = 2.27 m²·K/W
  //  R_conv ≈ 0.17 m²·K/W (inner + outer film)
  //  U_total = 1 / (2.27 + 0.17) ≈ 0.41 W/(m²·K)
  //  Standing loss ≈ 1.5–2.0 kWh/day at ΔT = 45 K  →  ErP Class A/B (2015)
  // ---------------------------------------------------------------
  parameter Real U_insulation = 0.41
    "Overall heat-loss coefficient  [W/(m²·K)]";
  parameter Real UA = U_insulation * A_surface
    "Lumped UA value  [W/K]";

  // ---------------------------------------------------------------
  //  Heater
  // ---------------------------------------------------------------
  parameter Real P_heater  = 2000.0
    "Rated heater power  [W]";
  parameter Real T_cutoff  = 65.0
    "Thermostat cut-off temperature  [°C]";
  parameter Real T_restart = 60.0
    "Thermostat switch-on temperature  [°C]  (5 K hysteresis)";

  // ---------------------------------------------------------------
  //  Environment
  // ---------------------------------------------------------------
  parameter Real T_amb_degC = 20.0
    "Ambient / room temperature  [°C]";

  // ---------------------------------------------------------------
  //  Initial condition
  // ---------------------------------------------------------------
  parameter Real T_init_degC = 20.0
    "Initial bulk water temperature  [°C]";


  // ---------------------------------------------------------------
  //  Internal variables
  // ---------------------------------------------------------------
  Boolean heater_on(start = true)  "Internal thermostat state";
  Real    P_actual                 "Heater power actually delivered  [W]";
  Real    Q_loss                   "Heat loss through tank wall + insulation  [W]";

equation
  heater_on = u_enable and
              not (T_water >= T_cutoff) and
              (if pre(heater_on) then true else T_water <= T_restart);

  P_actual = if heater_on then P_heater else 0.0;

  // ---------------------------------------------------------------
  //  Internal ODE – bulk water temperature
  //    m·cp · dT/dt = P_actual − UA·(T − T_amb)
  // ---------------------------------------------------------------
  Q_loss = UA * (T_water - T_amb_degC);

  m_water * cp_water * der(T_water) = P_actual - Q_loss;

  der(y_E_consumed) = P_actual;

  // ---------------------------------------------------------------
  //  Output assignments
  // ---------------------------------------------------------------
  y_heater_on       = heater_on;
  y_P_actual        = P_actual;
  y_E_consumed_kWh  = y_E_consumed / 3.6e6;

initial equation
  y_E_consumed = 0.0;

  annotation (
    experiment(
      StopTime  = 7200,
      Interval  = 1,
      Tolerance = 1e-6),
    Documentation(info = "<html>
<h3>Warm-Water Tank – FMU Model (v2)</h3>
<p>
  200-litre domestic hot-water storage cylinder with FMI 2.0 inputs/outputs.
</p>

<h4>FMI Interface</h4>
<table border='1' cellspacing='0' cellpadding='4'>
  <tr><th>Name</th><th>Causality</th><th>Type</th><th>Unit</th><th>Description</th></tr>
  <tr><td>u_enable</td><td>input</td><td>Boolean</td><td>–</td>
      <td>Enables (true) or forces off (false) the heating element</td></tr>
  <tr><td>T_water</td><td>input</td><td>Real</td><td>°C</td>
      <td>Measured water temperature from the master simulator</td></tr>
  <tr><td>y_heater_on</td><td>output</td><td>Boolean</td><td>–</td>
      <td>true when the element is energised</td></tr>
  <tr><td>y_P_actual</td><td>output</td><td>Real</td><td>W</td>
      <td>Instantaneous electrical power draw</td></tr>
  <tr><td>y_E_consumed</td><td>output</td><td>Real</td><td>J</td>
      <td>Cumulative electrical energy consumed since t = 0</td></tr>
  <tr><td>y_E_consumed_kWh</td><td>output</td><td>Real</td><td>kWh</td>
      <td>Same as above, converted to kWh</td></tr>
</table>

<h4>Stand-alone vs. co-simulation use</h4>
<p>
  When used <b>stand-alone</b> (e.g. OMEdit simulation), set<br/>
  <code>T_water = T_internal_degC</code> and <code>u_enable = true</code>
  to let the model drive itself.<br/>
  When used in a <b>co-simulation</b> loop, the master feeds a real
  sensor measurement into <code>T_water</code> and can toggle
  <code>u_enable</code> (e.g. from a smart-home controller).
</p>

<h4>Physical parameters</h4>
<table border='1' cellspacing='0' cellpadding='4'>
  <tr><th>Symbol</th><th>Value</th><th>Unit</th><th>Description</th></tr>
  <tr><td>V_tank</td><td>0.200</td><td>m³</td><td>Tank volume (200 L)</td></tr>
  <tr><td>P_heater</td><td>2000</td><td>W</td><td>Rated heater power</td></tr>
  <tr><td>T_cutoff</td><td>65</td><td>°C</td><td>Thermostat cut-off</td></tr>
  <tr><td>T_restart</td><td>60</td><td>°C</td><td>Thermostat restart (hysteresis)</td></tr>
  <tr><td>U_insulation</td><td>0.41</td><td>W/(m²·K)</td><td>Overall heat-loss coefficient</td></tr>
  <tr><td>A_surface</td><td>1.87</td><td>m²</td><td>Tank outer surface area</td></tr>
  <tr><td>T_amb_degC</td><td>20</td><td>°C</td><td>Ambient temperature</td></tr>
</table>

<h4>Export as FMU 2.0</h4>
<pre>
  omc export_fmu.mos
</pre>
<p>or in OMEdit: <i>FMI &rarr; Export FMU &rarr; FMI 2.0, Co-Simulation or Model Exchange</i></p>
</html>"));

end WarmWaterTank;
