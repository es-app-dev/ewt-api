namespace EWT.Data.Models;

public partial class LicenseEntity
{
    public int LicenseId { get; set; }

    public int? DropKey1 { get; set; }

    public int? PicklistIdRadiologic { get; set; }

    public int? DropKey2 { get; set; }

    public int? PicklistIdLicense { get; set; }

    public float? ActivityLimit { get; set; }

    public float? IhiFactor { get; set; }

    public float? EhiFactor { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity? CurrentStatus { get; set; }
}