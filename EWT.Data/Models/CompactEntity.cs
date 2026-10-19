namespace EWT.Data.Models;

public partial class CompactEntity
{
    public int CompactId { get; set; }

    public int? DropKey { get; set; }

    public string? Description { get; set; }

    public string? Address1 { get; set; }

    public string? Address2 { get; set; }

    public string? City { get; set; }

    public int? PicklistStateId { get; set; }

    public string? Zip { get; set; }

    public string? Contact { get; set; }

    public string? Title { get; set; }

    public string? Fax { get; set; }

    public string? Phone { get; set; }

    public string? Email { get; set; }

    public bool PetitionRequiredFlag { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity CurrentStatus { get; set; } = null!;
}
