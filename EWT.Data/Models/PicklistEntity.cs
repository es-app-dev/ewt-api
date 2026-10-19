namespace EWT.Data.Models;

public partial class PicklistEntity
{
    public int PicklistId { get; set; }

    public int? DropKey { get; set; }

    public string Type { get; set; } = null!;

    public string Code { get; set; } = null!;

    public string Description { get; set; } = null!;

    public string? Pickorder { get; set; }

    public string? Additional1 { get; set; }
    public string? Additional2 { get; set; }

    public int? NumberValue1 { get; set; }

    public int? NumberValue2 { get; set; }

    public int? NumberValue3 { get; set; }

    public string? StringValue1 { get; set; }

    public string? StringValue2 { get; set; }

    public string? StringValue3 { get; set; }

    public string? StringValue4 { get; set; }

    public string? Wastetype1 { get; set; }

    public string? Wastetype2 { get; set; }

    public string? Wastetype3 { get; set; }

    public int? HighValue { get; set; }

    public int? LowValue { get; set; }

    public DateTime? InactiveDate { get; set; }

    public bool WsIsotopeLimitFlag { get; set; }

    public bool IsotopeSnmFlag { get; set; }

    public bool Isotope29eFlag { get; set; }

    public string? ReportType { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity? CurrentStatus { get; set; }
}
