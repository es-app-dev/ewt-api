namespace EWT.Data.Models;

public partial class EwtUserUserRoleMapEntity
{
    public int EwtUserUserRoleMapId { get; set; }

    public int EwtUserId { get; set; }

    public int UserRoleId { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity? CurrentStatus { get; set; }

    public virtual EwtUserEntity? EwtUser { get; set; }

    public virtual UserRoleEntity? UserRole { get; set; }
}
