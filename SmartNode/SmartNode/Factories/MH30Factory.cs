using Logic.TTComponentInterfaces;
using Logic.FactoryInterface;
using Implementations.Sensors.HomeAssistant;
using Microsoft.Extensions.Configuration;
using System.Diagnostics;
using Implementations.Actuators.HomeAssistant;

namespace SmartNode.Factories {
    public class MH30Factory : AbstractFactory, IFactory
    {

        protected override IDictionary<string, IActuator> MakeActuatorMap(IServiceProvider serviceProvider)
        {
            return new Dictionary<string, IActuator> {
                            {
                                "http://www.semanticweb.org/vs/ontologies/2026/05/mh30#WaterHeaterActuator",
                                new HomeAssistantActuator("http://www.semanticweb.org/vs/ontologies/2026/05/mh30#WaterHeaterActuator",
                                "switch.ikea_of_sweden_tradfri_control_outlet_switch",
                                // "switch.socket_warm_water_switch",
                                HomeAssistantActuator.ActuatorKind.Switch, _httpClient,
                                    null)
                            }
            };
        }

        protected override IDictionary<(string, string), ISensor> MakeSensorMap(IServiceProvider serviceProvider)
        {
            return new Dictionary<(string, string), ISensor> {
                            {
                                ("http://www.semanticweb.org/vs/ontologies/2026/05/mh30#TempSensor",
                                "http://www.semanticweb.org/vs/ontologies/2026/05/mh30#TempProcedure"),
                                new HomeAssistantSensor("http://www.semanticweb.org/vs/ontologies/2026/05/mh30#T_water",
                                    "sensor.water_temperature", null, _httpClient)
                            }
                    };
        }
        protected override IDictionary<string, IConfigurableParameter> MakeConfigurableParameterMap(IServiceProvider serviceProvider)
        {
            return new Dictionary<string, IConfigurableParameter>();
        }

        private static HttpClient _httpClient;

        private readonly record struct Wrapped(IServiceProvider ServiceProvider);
        public MH30Factory(IServiceProvider serviceProvider) : this(Wrapper(serviceProvider)) {}
        private MH30Factory(Wrapped w) : base(w.ServiceProvider) { }

        private static Wrapped Wrapper(IServiceProvider serviceProvider)
        {
            // Make sure that we always have the Incubator initialised.
            // Inspired by https://stackoverflow.com/q/12051/60462
            var handler = new SocketsHttpHandler
            {
                PooledConnectionLifetime = TimeSpan.FromMinutes(2)
            };
            var secrets = new ConfigurationBuilder().AddUserSecrets<MH30Factory>().Build();

            var haURI = Environment.GetEnvironmentVariable("MH30_HA_URI") ?? "localhost";
            var TOKEN = secrets["HA:TOKEN"];
            Debug.Assert(TOKEN != null, $"No token for host {haURI}.");

            _httpClient = new HttpClient(handler, disposeHandler: false)
            {
                BaseAddress = new Uri(haURI)
            };
            _httpClient.DefaultRequestHeaders.Add("Authorization", $"Bearer {TOKEN}");
            _httpClient.DefaultRequestHeaders.Add("User-Agent", "SmartNodeTestClient/1.0");
            return new Wrapped(serviceProvider);
        }
    }
}
