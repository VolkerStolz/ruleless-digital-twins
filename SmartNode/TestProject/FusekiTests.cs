using System.Reflection;
using VDS.RDF;
using VDS.RDF.Parsing;
using VDS.RDF.Query;
using VDS.RDF.Storage;
using VDS.RDF.Writing;

namespace TestProject {
    // Integration tests; these require the Fuseki server of the devcontainer to be running on localhost:3030.
    public class FusekiTests {
        private const string DatasetUri = "http://localhost:3030/ds/data";
        private const string InferenceUri = "http://localhost:3030/inf/data";

        private static string ModelFilepath {
            get {
                var rootDirectory = Directory.GetParent(Assembly.GetExecutingAssembly().Location)!.Parent!.Parent!.Parent!.Parent!.Parent!.FullName;
                return Path.Combine(rootDirectory, "models-and-rules", "M370.ttl");
            }
        }

        // Replaces the default graph of the dataset; idempotent, so every test can establish its own precondition.
        private static void UploadModel(FusekiConnector connector) {
            var model = new Graph();
            new TurtleParser().Load(model, ModelFilepath);
            // The Turtle base IRI would otherwise make the connector store the model in a named graph.
            model.BaseUri = null;
            connector.SaveGraph(model);
        }

        [Fact]
        public void M370_uploads_to_Fuseki() {
            using var connector = new FusekiConnector(new Uri(DatasetUri));
            var expectedModel = new Graph();
            new TurtleParser().Load(expectedModel, ModelFilepath);

            UploadModel(connector);

            var result = Assert.IsType<SparqlResultSet>(connector.Query("SELECT (COUNT(*) AS ?count) WHERE { ?s ?p ?o }"));
            var uploadedTripleCount = int.Parse(((ILiteralNode)result.Single()["count"]).Value);
            Assert.Equal(expectedModel.Triples.Count, uploadedTripleCount);
        }

        [Fact]
        public void Fuseki_returns_FMU_referenced_from_platform() {
            using var connector = new FusekiConnector(new Uri(DatasetUri));
            UploadModel(connector);

            var result = connector.Query("""
                PREFIX sosa: <http://www.w3.org/ns/sosa/>
                PREFIX rdt: <http://www.semanticweb.org/ivans/ontologies/2025/ruleless-digital-twins/>
                SELECT ?platform ?fmu WHERE {
                    ?platform a sosa:Platform ;
                              rdt:hasSimulationModel ?fmu .
                }
                """);

            var resultSet = Assert.IsType<SparqlResultSet>(result);
            Assert.True(resultSet.Result);
            Assert.NotEmpty(resultSet.Results);
            Assert.Contains(resultSet.Results, r => r["fmu"].ToString().EndsWith("#RoomM370FMU"));
        }

        [Fact]
        public void Fuseki_applies_inference_rules_to_model() {
            using var dataConnector = new FusekiConnector(new Uri(DatasetUri));
            UploadModel(dataConnector);

            // The /inf service of the Fuseki configuration applies the rules of App.java to the model put into it.
            using var inferenceConnector = new FusekiConnector(new Uri(InferenceUri));
            IGraph inferredModel;
            try {
                var model = new Graph();
                dataConnector.LoadGraph(model, (Uri?)null);
                inferenceConnector.SaveGraph(model);
                inferredModel = Assert.IsAssignableFrom<IGraph>(inferenceConnector.Query("CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }"));
            } catch (Exception exception) {
                // Surfaces the error returned by Fuseki.
                Console.Error.WriteLine($"Fuseki returned an error: {exception}");
                throw;
            }

            var originalModel = new Graph();
            new TurtleParser().Load(originalModel, ModelFilepath);
            Assert.True(inferredModel.Triples.Count > originalModel.Triples.Count, "No triples were inferred.");

            // The compressing writer overflows the stack on the cyclic collections introduced by inference.            new TurtleWriter().Save(inferredModel, Console.Out);
        }
    }
}
