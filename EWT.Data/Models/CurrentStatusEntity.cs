namespace EWT.Data.Models;

public partial class CurrentStatusEntity
{
    public int CurrentStatusId { get; set; }

    public string? CurrentStatusDescription { get; set; }

    public string CreatedBy { get; set; } = null!;

    public DateTime CreatedDate { get; set; }

    public string UpdatedBy { get; set; } = null!;

    public DateTime UpdatedDate { get; set; }

    public virtual ICollection<AreaEntity> Areas { get; set; } = new List<AreaEntity>();

    public virtual ICollection<ChecklistAnswerEntity> ChecklistAnswers { get; set; } = new List<ChecklistAnswerEntity>();

    public virtual ICollection<ChecklistEntity> Checklists { get; set; } = new List<ChecklistEntity>();

    public virtual ICollection<CompactStateEntity> CompactStates { get; set; } = new List<CompactStateEntity>();

    public virtual ICollection<CompactEntity> Compacts { get; set; } = new List<CompactEntity>();

    public virtual ICollection<ContainerEntity> Containers { get; set; } = new List<ContainerEntity>();

    public virtual ICollection<ContractDuWaiverEntity> ContractDuWaivers { get; set; } = new List<ContractDuWaiverEntity>();

    public virtual ICollection<ContractSapEntity> ContractSaps { get; set; } = new List<ContractSapEntity>();

    public virtual ICollection<ContractWasteTypeEntity> ContractWasteTypes { get; set; } = new List<ContractWasteTypeEntity>();

    public virtual ICollection<ContractEntity> Contracts { get; set; } = new List<ContractEntity>();

    public virtual ICollection<DisposalEntity> Disposals { get; set; } = new List<DisposalEntity>();

    public virtual ICollection<GeneratorEntity> Generators { get; set; } = new List<GeneratorEntity>();

    public virtual ICollection<EwtUserUserRoleMapEntity> EwtUserUserRoleMaps { get; set; } = new List<EwtUserUserRoleMapEntity>();

    public virtual ICollection<EwtUserEntity> EwtUsers { get; set; } = new List<EwtUserEntity>();

    public virtual ICollection<PicklistEntity> Picklists { get; set; } = new List<PicklistEntity>();

    public virtual ICollection<ShipmentDetailEntity> ShipmentDetails { get; set; } = new List<ShipmentDetailEntity>();

    public virtual ICollection<ShipmentDotEntity> ShipmentDots { get; set; } = new List<ShipmentDotEntity>();

    public virtual ICollection<ShipmentEntity> Shipments { get; set; } = new List<ShipmentEntity>();

    public virtual ICollection<SiteAccessPermitEntity> SiteAccessPermits { get; set; } = new List<SiteAccessPermitEntity>();

    public virtual ICollection<StorageEntity> Storages { get; set; } = new List<StorageEntity>();

    public virtual ICollection<UserRoleEntity> UserRoles { get; set; } = new List<UserRoleEntity>();
}
