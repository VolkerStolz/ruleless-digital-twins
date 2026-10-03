namespace Logic.Models.MapekModels {
    public class FusekiArguments {
        // Graph Store endpoint of the dataset holding the instance model.
        public string InstanceModelUri { get; set; } = "http://localhost:3030/ds/data";

        // Graph Store endpoint of the service that applies the inference rules to the model put into it.
        public string InferredModelUri { get; set; } = "http://localhost:3030/inf/data";
    }
}
