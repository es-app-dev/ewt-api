namespace EWT.Data.Models;

public partial class ShipmentEntity
{
    public int ShipmentId { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity CurrentStatus { get; set; } = null!;
}
