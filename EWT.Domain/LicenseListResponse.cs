namespace EWT.Domain
{
    class LicenseListResponse
    {
        public string? Radionuclide { get; set; }
        public float? ActivityLimit { get; set; }
        public string? License { get; set; }
        public float? IhiFactor { get; set; }
        public float? EhiFactor { get; set; }
    }
}
