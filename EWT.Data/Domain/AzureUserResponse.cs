using System.Text.Json.Serialization;

namespace EWT.Data.Domain
{
    public class AzureAdUserResponse
    {
        [JsonPropertyName("value")]
        public List<AzureAdUser> Value { get; set; }

        [JsonPropertyName("@odata.nextLink")]
        public string NextLink { get; set; }
    }
}
