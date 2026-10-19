using EWT.Data.Domain;
using EWT.Data.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;

namespace EWT.Data;

public partial class EwtContext : DbContext
{
    private readonly IConfiguration _configuration;
    public EwtContext(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public EwtContext(DbContextOptions<EwtContext> options, IConfiguration configuration)
        : base(options)
    {
        _configuration = configuration;
    }


    public virtual DbSet<AreaEntity> Areas { get; set; }

    public virtual DbSet<ChecklistEntity> Checklists { get; set; }

    public virtual DbSet<ChecklistAnswerEntity> ChecklistAnswers { get; set; }

    public virtual DbSet<CompactEntity> Compacts { get; set; }

    public virtual DbSet<CompactStateEntity> CompactStates { get; set; }

    public virtual DbSet<ContainerEntity> Containers { get; set; }

    public virtual DbSet<ContractEntity> Contracts { get; set; }

    public virtual DbSet<ContractDuWaiverEntity> ContractDuWaivers { get; set; }

    public virtual DbSet<ContractSapEntity> ContractSaps { get; set; }

    public virtual DbSet<ContractWasteTypeEntity> ContractWasteTypes { get; set; }

    public virtual DbSet<CurrentStatusEntity> CurrentStatuses { get; set; }

    public virtual DbSet<DisposalEntity> Disposals { get; set; }

    public virtual DbSet<EwtUserEntity> EwtUsers { get; set; }

    public virtual DbSet<EwtUserUserRoleMapEntity> EwtUserUserRoleMaps { get; set; }

    public virtual DbSet<GeneratorEntity> Generators { get; set; }

    public virtual DbSet<LicenseEntity> Licenses { get; set; }

    public virtual DbSet<PicklistEntity> Picklists { get; set; }

    public virtual DbSet<ShipmentEntity> Shipments { get; set; }

    public virtual DbSet<ShipmentDetailEntity> ShipmentDetails { get; set; }

    public virtual DbSet<ShipmentDotEntity> ShipmentDots { get; set; }

    public virtual DbSet<SiteAccessPermitEntity> SiteAccessPermits { get; set; }

    public virtual DbSet<StorageEntity> Storages { get; set; }

    public virtual DbSet<UserRoleEntity> UserRoles { get; set; }

    public virtual DbSet<LicenseListResponse> LicenseList { get; set; }

    public virtual DbSet<LicenseChildrenListResponse> LicenseChildrenList { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        optionsBuilder.UseSqlServer(_configuration.GetConnectionString("EWT_Database"));
    }
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<AreaEntity>(entity =>
        {
            entity.HasKey(e => e.AreaId).HasName("PK__area__985D6D6BFD93B233");

            entity.ToTable("area");

            entity.Property(e => e.AreaId).HasColumnName("area_id");
            entity.Property(e => e.AreaDescription)
                .HasMaxLength(500)
                .HasColumnName("area_description");
            entity.Property(e => e.AreaName)
                .HasMaxLength(500)
                .HasColumnName("area_name");
            entity.Property(e => e.Comments)
                .HasMaxLength(500)
                .HasColumnName("comments");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.EndDateActive)
                .HasColumnType("datetime")
                .HasColumnName("end_date_active");
            entity.Property(e => e.TypeCode)
                .HasMaxLength(50)
                .HasColumnName("type_code");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Areas)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_area_current_status");
        });

        modelBuilder.Entity<ChecklistEntity>(entity =>
        {
            entity.HasKey(e => e.ChecklistId).HasName("PK__checklis__23C471C58C67D274");

            entity.ToTable("checklist");

            entity.Property(e => e.ChecklistId).HasColumnName("checklist_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Checklists)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_checklist_current_status");
        });

        modelBuilder.Entity<ChecklistAnswerEntity>(entity =>
        {
            entity.HasKey(e => e.ChecklistAnswerId).HasName("PK__checklis__52BF220D811BA00A");

            entity.ToTable("checklist_answer");

            entity.Property(e => e.ChecklistAnswerId)
                .ValueGeneratedNever()
                .HasColumnName("checklist_answer");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ChecklistAnswers)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_checklist_answer_current_status");
        });

        modelBuilder.Entity<CompactEntity>(entity =>
        {
            entity.HasKey(e => e.CompactId).HasName("PK__compact__14EC7CCE8B6E251D");

            entity.ToTable("compact");

            entity.Property(e => e.CompactId).HasColumnName("compact_id");
            entity.Property(e => e.Address1)
                .HasMaxLength(500)
                .HasColumnName("address_1");
            entity.Property(e => e.Address2)
                .HasMaxLength(500)
                .HasColumnName("address_2");
            entity.Property(e => e.City)
                .HasMaxLength(500)
                .HasColumnName("city");
            entity.Property(e => e.Contact)
                .HasMaxLength(500)
                .HasColumnName("contact");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .HasColumnName("description");
            entity.Property(e => e.Email)
                .HasMaxLength(500)
                .HasColumnName("email");
            entity.Property(e => e.Fax)
                .HasMaxLength(30)
                .HasColumnName("fax");
            entity.Property(e => e.PetitionRequiredFlag).HasColumnName("petition_required_flag");
            entity.Property(e => e.Phone)
                .HasMaxLength(30)
                .HasColumnName("phone");
            entity.Property(e => e.PicklistStateId).HasColumnName("picklist_state_id");
            entity.Property(e => e.Title)
                .HasMaxLength(30)
                .HasColumnName("title");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.Zip)
                .HasMaxLength(30)
                .HasColumnName("zip");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Compacts)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_compact_current_status");
        });

        modelBuilder.Entity<CompactStateEntity>(entity =>
        {
            entity.HasKey(e => e.CompactStateId).HasName("PK__compact___EB03A5A44E20D812");

            entity.ToTable("compact_state");

            entity.Property(e => e.CompactStateId)
                .ValueGeneratedNever()
                .HasColumnName("compact_state");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.CompactStates)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_compact_state_current_status");
        });

        modelBuilder.Entity<ContainerEntity>(entity =>
        {
            entity.HasKey(e => e.ContainerId).HasName("PK__containe__48725BD9AAA4C250");

            entity.ToTable("container");

            entity.Property(e => e.ContainerId)
                .ValueGeneratedNever()
                .HasColumnName("container_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Containers)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_container_current_status");
        });

        modelBuilder.Entity<ContractEntity>(entity =>
        {
            entity.HasKey(e => e.ContractId).HasName("PK__contract__F8D7B564C8E02B5D");

            entity.ToTable("contract");

            entity.Property(e => e.ContractId)
                .ValueGeneratedNever()
                .HasColumnName("contract_od");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Contracts)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_contract_current_status");
        });

        modelBuilder.Entity<ContractDuWaiverEntity>(entity =>
        {
            entity.HasKey(e => e.ContractDuWaiverId).HasName("PK__contract__7E2327A21D52BB77");

            entity.ToTable("contract_du_waiver");

            entity.Property(e => e.ContractDuWaiverId)
                .ValueGeneratedNever()
                .HasColumnName("contract_du_waiver_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ContractDuWaivers)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_contract_du_waiver_current_status");
        });

        modelBuilder.Entity<ContractSapEntity>(entity =>
        {
            entity.HasKey(e => e.ContractSap1).HasName("PK__contract__EF085C9CDB45EBE2");

            entity.ToTable("contract_sap");

            entity.Property(e => e.ContractSap1)
                .ValueGeneratedNever()
                .HasColumnName("contract_sap");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ContractSaps)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_contract_sap_current_status");
        });

        modelBuilder.Entity<ContractWasteTypeEntity>(entity =>
        {
            entity.HasKey(e => e.ContractWasteType1).HasName("PK__contract__1813DDC84BEA0F72");

            entity.ToTable("contract_waste_type");

            entity.Property(e => e.ContractWasteType1)
                .ValueGeneratedNever()
                .HasColumnName("contract_waste_type");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ContractWasteTypes)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_contract_waste_type_current_status");
        });

        modelBuilder.Entity<CurrentStatusEntity>(entity =>
        {
            entity.HasKey(e => e.CurrentStatusId).HasName("PK__current___E807147BB6B51DB1");

            entity.ToTable("current_status");

            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusDescription)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("current_status_description");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
        });

        modelBuilder.Entity<DisposalEntity>(entity =>
        {
            entity.HasKey(e => e.DisposalId).HasName("PK__disposal__0F02C4744CEFD418");

            entity.ToTable("disposal");

            entity.Property(e => e.DisposalId)
                .ValueGeneratedNever()
                .HasColumnName("disposal_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Disposals)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_disposal_current_status");
        });

        modelBuilder.Entity<EwtUserEntity>(entity =>
        {
            entity.HasKey(e => e.EwtUserId).HasName("PK__ewt_use__6D86B1DDBC910B60");

            entity.ToTable("ewt_user");

            entity.Property(e => e.EwtUserId).HasColumnName("ewt_user_id");
            entity.Property(e => e.DropKey).HasColumnName("drop_key");
            entity.Property(e => e.Bd).HasColumnName("bd");
            entity.Property(e => e.CntrConcLimitWarnFlag).HasColumnName("cntr_conc_limit_warn_flag");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.Ee).HasColumnName("ee");
            entity.Property(e => e.Email)
                .HasMaxLength(200)
                .HasColumnName("email");
            entity.Property(e => e.EwtAdministratorFlag).HasColumnName("ewt_administrator_flag");
            entity.Property(e => e.GenShipThruProcsrWarnFlag).HasColumnName("gen_ship_thru_procsr_warn_flag");
            entity.Property(e => e.Inspector).HasColumnName("inspector");
            entity.Property(e => e.ManifestLoadErrorFlag).HasColumnName("manifest_load_error_flag");
            entity.Property(e => e.NewCntrClassWarnFlag).HasColumnName("new_cntr_class_warn_flag");
            entity.Property(e => e.NewCntrIhiWarnFlag).HasColumnName("new_cntr_ihi_warn_flag");
            entity.Property(e => e.Ops).HasColumnName("ops");
            entity.Property(e => e.PalWarningNotifyFlag).HasColumnName("pal_warning_notify_flag");
            entity.Property(e => e.Qa).HasColumnName("qa");
            entity.Property(e => e.QcAccount).HasColumnName("qc_account");
            entity.Property(e => e.ReadonlyFlg).HasColumnName("readonly_flg");
            entity.Property(e => e.Rpm).HasColumnName("rpm");
            entity.Property(e => e.ShipArrivedChangedWarnFlag).HasColumnName("ship_arrived_changed_warn_flag");
            entity.Property(e => e.ShipConcLimitWarnFlag).HasColumnName("ship_conc_limit_warn_flag");
            entity.Property(e => e.Sm).HasColumnName("sm");
            entity.Property(e => e.SpecialHandlingWarnFlag).HasColumnName("special_handling_warn_flag");
            entity.Property(e => e.Srso).HasColumnName("srso");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.UserName)
                .HasMaxLength(200)
                .HasColumnName("user_name");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.EwtUsers)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ewt_user_current_status");
        });

        modelBuilder.Entity<EwtUserUserRoleMapEntity>(entity =>
        {
            entity.HasKey(e => e.EwtUserUserRoleMapId).HasName("PK__ewt_use__661732082E655D52");

            entity.ToTable("ewt_user_user_role_map");

            entity.Property(e => e.EwtUserUserRoleMapId).HasColumnName("ewt_user_user_role_map_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.EwtUserId).HasColumnName("ewt_user_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.UserRoleId).HasColumnName("user_role_id");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.EwtUserUserRoleMaps)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ewt_user_user_role_map_current_status");

            entity.HasOne(d => d.EwtUser).WithMany(p => p.EwtUserUserRoleMaps)
                .HasForeignKey(d => d.EwtUserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ewt_user_user_role_map_ewt_user");

            entity.HasOne(d => d.UserRole).WithMany(p => p.EwtUserUserRoleMaps)
                .HasForeignKey(d => d.UserRoleId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ewt_user_user_role_map_user_role");
        });

        modelBuilder.Entity<GeneratorEntity>(entity =>
        {
            entity.HasKey(e => e.GeneratorId).HasName("PK__generato__EE7AD2DC19018AFB");

            entity.ToTable("generator");

            entity.Property(e => e.GeneratorId).HasColumnName("generator_id");
            entity.Property(e => e.Address1).HasColumnName("address1");
            entity.Property(e => e.Address2).HasColumnName("address2");
            entity.Property(e => e.City).HasColumnName("city");
            entity.Property(e => e.Contact).HasColumnName("contact");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.DropKey).HasColumnName("drop_key");
            entity.Property(e => e.DropKeyPicklistState).HasColumnName("drop_key_picklist_state");
            entity.Property(e => e.Email).HasColumnName("email");
            entity.Property(e => e.Fax)
                .HasMaxLength(30)
                .HasColumnName("fax");
            entity.Property(e => e.GeneratorName).HasColumnName("generator_name");
            entity.Property(e => e.GeneratorNumber)
                .HasMaxLength(10)
                .HasColumnName("generator_number");
            entity.Property(e => e.Note).HasColumnName("note");
            entity.Property(e => e.Phone)
                .HasMaxLength(30)
                .HasColumnName("phone");
            entity.Property(e => e.PicklistIdState).HasColumnName("picklist_id_state");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.Zip).HasColumnName("zip");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Generators)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_generator_current_status");
        });

        modelBuilder.Entity<LicenseEntity>(entity =>
        {
            entity.HasKey(e => e.LicenseId).HasName("PK__license__BBBB757807CE300F");

            entity.ToTable("license");

            entity.Property(e => e.LicenseId).HasColumnName("license_id");
            entity.Property(e => e.DropKey1).HasColumnName("dropkey1");
            entity.Property(e => e.DropKey2).HasColumnName("dropkey2");
            entity.Property(e => e.ActivityLimit)
                .HasColumnType("float(53)")
                .HasColumnName("activity_limit");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.EhiFactor)
                .HasColumnType("float(53)")
                .HasColumnName("ehi_factor");
            entity.Property(e => e.IhiFactor)
                .HasColumnType("float(53)")
                .HasColumnName("ihi_factor");
            entity.Property(e => e.PicklistIdLicense).HasColumnName("picklist_id_license");
            entity.Property(e => e.PicklistIdRadiologic).HasColumnName("picklist_id_radiologic");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
        });

        modelBuilder.Entity<PicklistEntity>(entity =>
        {
            entity.HasKey(e => e.PicklistId).HasName("PK__picklist__3769A1196023E7E2");

            entity.ToTable("picklist");

            entity.Property(e => e.PicklistId).HasColumnName("picklist_id");
            entity.Property(e => e.DropKey).HasColumnName("drop_key");
            entity.Property(e => e.Additional1)
                .HasMaxLength(250)
                .HasColumnName("additional_1");
            entity.Property(e => e.Additional2)
    .HasMaxLength(250)
    .HasColumnName("additional_2");
            entity.Property(e => e.Code)
                .HasMaxLength(50)
                .HasColumnName("code");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.Description)
                .HasMaxLength(200)
                .HasColumnName("description");
            entity.Property(e => e.HighValue).HasColumnName("high_value");
            entity.Property(e => e.InactiveDate)
                .HasColumnType("datetime")
                .HasColumnName("inactive_date");
            entity.Property(e => e.Isotope29eFlag).HasColumnName("isotope_29e_flag");
            entity.Property(e => e.IsotopeSnmFlag).HasColumnName("isotope_snm_flag");
            entity.Property(e => e.LowValue).HasColumnName("low_value");
            entity.Property(e => e.NumberValue1).HasColumnName("number_value_1");
            entity.Property(e => e.NumberValue2).HasColumnName("number_value_2");
            entity.Property(e => e.NumberValue3).HasColumnName("number_value_3");
            entity.Property(e => e.Pickorder)
                .HasMaxLength(50)
                .HasColumnName("pickorder");
            entity.Property(e => e.ReportType)
                .HasMaxLength(50)
                .HasColumnName("report_type");
            entity.Property(e => e.StringValue1)
                .HasMaxLength(250)
                .HasColumnName("string_value_1");
            entity.Property(e => e.StringValue2)
                .HasMaxLength(250)
                .HasColumnName("string_value_2");
            entity.Property(e => e.StringValue3)
                .HasMaxLength(250)
                .HasColumnName("string_value_3");
            entity.Property(e => e.StringValue4)
                .HasMaxLength(250)
                .HasColumnName("string_value_4");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .HasColumnName("type");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.Wastetype1)
                .HasMaxLength(250)
                .HasColumnName("wastetype_1");
            entity.Property(e => e.Wastetype2)
                .HasMaxLength(250)
                .HasColumnName("wastetype_2");
            entity.Property(e => e.Wastetype3)
                .HasMaxLength(250)
                .HasColumnName("wastetype_3");
            entity.Property(e => e.WsIsotopeLimitFlag).HasColumnName("ws_isotope_limit_flag");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Picklists)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_picklist_current_status");
        });

        modelBuilder.Entity<ShipmentEntity>(entity =>
        {
            entity.HasKey(e => e.ShipmentId).HasName("PK__shipment__41466E59AEB27E79");

            entity.ToTable("shipment");

            entity.Property(e => e.ShipmentId)
                .ValueGeneratedNever()
                .HasColumnName("shipment_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Shipments)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_shipment_current_status");
        });

        modelBuilder.Entity<ShipmentDetailEntity>(entity =>
        {
            entity.HasKey(e => e.ShipmentDetailId).HasName("PK__shipment__D13A4ACAE0F4CB3C");

            entity.ToTable("shipment_detail");

            entity.Property(e => e.ShipmentDetailId)
                .ValueGeneratedNever()
                .HasColumnName("shipment_detail_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ShipmentDetails)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_shipment_detail_current_status");
        });

        modelBuilder.Entity<ShipmentDotEntity>(entity =>
        {
            entity.HasKey(e => e.ShipmentDotId).HasName("PK__shipment__9DBA2B8F1206DF82");

            entity.ToTable("shipment_dot");

            entity.Property(e => e.ShipmentDotId)
                .ValueGeneratedNever()
                .HasColumnName("shipment_dot_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.ShipmentDots)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_shipment_dot_current_status");
        });

        modelBuilder.Entity<SiteAccessPermitEntity>(entity =>
        {
            entity.HasKey(e => e.SiteAccessPermitId).HasName("PK__site_acc__34B407BCE4D7F3CD");

            entity.ToTable("site_access_permit");

            entity.Property(e => e.SiteAccessPermitId)
                .ValueGeneratedNever()
                .HasColumnName("site_access_permit_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.SiteAccessPermits)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_site_access_permit_current_status");
        });

        modelBuilder.Entity<StorageEntity>(entity =>
        {
            entity.HasKey(e => e.StorageId).HasName("PK__storage__AB53044AE0ACD0D9");

            entity.ToTable("storage");

            entity.Property(e => e.StorageId)
                .ValueGeneratedNever()
                .HasColumnName("storage_id");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.Storages)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_storage_current_status");
        });

        modelBuilder.Entity<UserRoleEntity>(entity =>
        {
            entity.HasKey(e => e.UserRoleId).HasName("PK__user_rol__B8D9ABA25926DBFD");

            entity.ToTable("user_role");

            entity.Property(e => e.UserRoleId).HasColumnName("user_role_id");
            entity.Property(e => e.DropKey).HasColumnName("drop_key");
            entity.Property(e => e.CreatedBy).HasColumnName("created_by");
            entity.Property(e => e.CreatedDate)
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentStatusId).HasColumnName("current_status_id");
            entity.Property(e => e.Override).HasColumnName("override");
            entity.Property(e => e.UpdatedBy).HasColumnName("updated_by");
            entity.Property(e => e.UpdatedDate)
                .HasColumnType("datetime")
                .HasColumnName("updated_date");
            entity.Property(e => e.UserRoleName)
                .HasMaxLength(200)
                .HasColumnName("user_role_name");

            entity.HasOne(d => d.CurrentStatus).WithMany(p => p.UserRoles)
                .HasForeignKey(d => d.CurrentStatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_user_role_current_status");
        });

        modelBuilder.Entity<LicenseListResponse>().HasNoKey();
        modelBuilder.Entity<LicenseChildrenListResponse>().HasNoKey();

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
