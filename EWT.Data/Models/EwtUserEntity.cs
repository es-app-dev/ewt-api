namespace EWT.Data.Models;

public partial class EwtUserEntity
{
    public int EwtUserId { get; set; }

    public int? DropKey { get; set; }

    public string UserName { get; set; } = null!;

    public string Email { get; set; } = null!;

    public bool Inspector { get; set; }

    public bool QcAccount { get; set; }

    public bool Sm { get; set; }

    public bool Srso { get; set; }

    public bool Rpm { get; set; }

    public bool Qa { get; set; }

    public bool Ee { get; set; }

    public bool Ops { get; set; }

    public bool Bd { get; set; }

    public bool PalWarningNotifyFlag { get; set; }

    public bool EwtAdministratorFlag { get; set; }

    public bool GenShipThruProcsrWarnFlag { get; set; }

    public bool ManifestLoadErrorFlag { get; set; }

    public bool SpecialHandlingWarnFlag { get; set; }

    public bool NewCntrIhiWarnFlag { get; set; }

    public bool ShipArrivedChangedWarnFlag { get; set; }

    public bool ReadonlyFlg { get; set; }

    public bool CntrConcLimitWarnFlag { get; set; }

    public bool ShipConcLimitWarnFlag { get; set; }

    public bool NewCntrClassWarnFlag { get; set; }

    public int CurrentStatusId { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual CurrentStatusEntity? CurrentStatus { get; set; }

    public virtual ICollection<EwtUserUserRoleMapEntity>? EwtUserUserRoleMaps { get; set; }
}
