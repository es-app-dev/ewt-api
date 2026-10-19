using EWT.Data.Interfaces;

namespace EWT.Data.Models;

public partial class AreaEntity
{
    public int AreaId { get; set; }

    public int? DropKey { get; set; }

    public string AreaName { get; set; } = null!;

    public string? AreaDescription { get; set; }

    public string TypeCode { get; set; } = null!;

    public DateTime? EndDateActive { get; set; }

    public string Comments { get; set; } = null!;

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity CurrentStatus { get; set; } = null!;
}
