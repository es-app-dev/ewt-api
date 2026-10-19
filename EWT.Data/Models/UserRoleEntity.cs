namespace EWT.Data.Models;

public partial class UserRoleEntity
{
    public int UserRoleId { get; set; }

    public int? DropKey { get; set; }

    public string UserRoleName { get; set; } = null!;

    public bool Override { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity? CurrentStatus { get; set; }

    public virtual ICollection<EwtUserUserRoleMapEntity>? EwtUserUserRoleMaps { get; set; }
}
