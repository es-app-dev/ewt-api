namespace EWT.Data.Domain
{
    public class LicenseChildrenListResponse
    {
        public int RadPicklistId { get; set; }
        public string? Radionuclide { get; set; }
        public double? ActivityLimit { get; set; }
        public int LicPicklistId { get; set; }
        public string? License { get; set; }
        public int LicenseId { get; set; }
        public double? IhiFactor { get; set; }
        public double? EhiFactor { get; set; }
    }
}
