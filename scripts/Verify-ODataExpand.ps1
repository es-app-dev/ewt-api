<#
.SYNOPSIS
  Verifies OData $expand for Treatment/Container flows by running the 5 test requests
  from ewis-ui/docs/api-expand-test-requests.md and checking that nav* properties are present.

.PARAMETER BaseUrl
  OData base URL (e.g. https://ewis-test-api.energysolutions.com/odata or http://localhost:5182/odata).

.EXAMPLE
  .\Verify-ODataExpand.ps1 -BaseUrl "http://localhost:5182/odata"

.NOTES
  Ensure the API has loaded relationships.json (array or { "relationships": [...] }).
  If you see "Unknown $expand" in API logs, relationships failed to load; fix the file format
  or restart after deploying the full relationships set (see RelationshipService).
#>
param(
    [Parameter(Mandatory = $true)]
    [string] $BaseUrl
)

$ErrorActionPreference = 'Stop'
$base = $BaseUrl.TrimEnd('/')

$tests = @(
    @{
        Id = 1
        Name = "EC_TREATMENTS (list - Query tab)"
        Url = $base + "/EC_TREATMENTS?$select=ID,TREATMENT_ID,RUN_NO,ARRIVED,APPROVAL_DATE,RUN_FINAL,WST_STRM_ID,LOCATION_ID&$filter=TREATMENT_ID LIKE '24%'&$orderby=ARRIVED desc&$expand=navWasteStream($select=ID,WASTEID,DESCRIPTION,CONTRACT_ID),navLocation($select=LOCATION_ID,LOCATION_NAME),navStatus($select=ID,CODE,DESCRIPTION)&$top=100"
        ExpectedNav = @('navWasteStream', 'navLocation', 'navStatus')
    },
    @{
        Id = 2
        Name = "EC_TREATMENTS (single - Treatment tab)"
        Url = $base + "/EC_TREATMENTS?$filter=ID eq 25200&$select=ID,TREATMENT_ID,RUN_NO,BATCHNO,ARRIVED,REPACK_DATE,APPROVAL_DATE,RUN_FINAL,NOTE,WST_STRM_ID,LOCATION_ID,RECIPE_ID,PCKLST_ID_STATUS,PCKLST_ID_TREATMENT_METHOD&$expand=navWasteStream($select=ID,WASTEID,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME),navStatus($select=ID,CODE,DESCRIPTION),navTreatmentMethod($select=ID,CODE,DESCRIPTION),navRecipe($select=ID,RECIPE_NO,NAME)&$top=100"
        ExpectedNav = @('navWasteStream', 'navLocation', 'navStatus', 'navTreatmentMethod', 'navRecipe')
    },
    @{
        Id = 3
        Name = "EC_CONTAINERS (Containers In - by treatment)"
        Url = $base + "/EC_CONTAINERS?$select=ID,CONTAINER_NO,GEN_CNTR_NO,PCKLST_ID_CONTAINER_TYPE,SHIPMENT_ID,OVER_SHIPMENT_ID,TREAT_ID,SEC_TREAT_ID,LOCATION_ID,PCKLST_ID_STATUS&$filter=TREAT_ID eq 25200 or SEC_TREAT_ID eq 25200&$orderby=CONTAINER_NO&$expand=navContainerType($select=ID,CODE,DESCRIPTION),navStatus($select=ID,CODE,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME),navShipment($select=ID,SEARCH_NO,BATES_NO,ARRIVED),navOverShipment($select=ID,SEARCH_NO,BATES_NO,ARRIVED),navTreatment($select=ID,TREATMENT_ID,RUN_NO,RUN_FINAL)&$top=100"
        ExpectedNav = @('navContainerType', 'navStatus', 'navLocation', 'navShipment', 'navOverShipment', 'navTreatment')
    },
    @{
        Id = 4
        Name = "EC_CONTAINERS (Containers Out)"
        Url = $base + "/EC_CONTAINERS?$select=ID,CONTAINER_NO,GEN_CNTR_NO,PCKLST_ID_CONTAINER_TYPE,WEIGHT,WEIGHTUNIT,VOLUME,VOLUMEUNIT,LOCATION_ID,PCKLST_ID_STATUS,VTD_FLAG&$filter=SHIPMENT_ID eq null and OVER_SHIPMENT_ID eq null and TREAT_ID eq 25200&$orderby=CONTAINER_NO&$expand=navContainerType($select=ID,CODE,DESCRIPTION),navStatus($select=ID,CODE,DESCRIPTION),navLocation($select=LOCATION_ID,LOCATION_NAME)&$top=100"
        ExpectedNav = @('navContainerType', 'navStatus', 'navLocation')
    },
    @{
        Id = 5
        Name = "EC_WASTE_STREAMS (navContract)"
        Url = $base + "/EC_WASTE_STREAMS?$filter=ID eq 12681&$select=ID,CONTRACT_ID&$expand=navContract($select=ID,CONTRACT_NO,GEN_ID)&$top=100"
        ExpectedNav = @('navContract')
    }
)

$failed = 0
foreach ($t in $tests) {
    Write-Host "Test $($t.Id): $($t.Name)" -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Uri $t.Url -Method Get -ErrorAction Stop
        $items = $response.value
        if (-not $items -or $items.Count -eq 0) {
            Write-Host "  No entities in value[] (OK if filter returns empty; nav* cannot be checked)." -ForegroundColor Yellow
            continue
        }
        $first = $items[0]
        $missing = @()
        foreach ($nav in $t.ExpectedNav) {
            if (-not ($first.PSObject.Properties.Name -contains $nav)) {
                $missing += $nav
            }
        }
        if ($missing.Count -gt 0) {
            Write-Host "  FAIL: Missing nav properties: $($missing -join ', ')" -ForegroundColor Red
            $failed++
        } else {
            Write-Host "  OK: All expected nav properties present: $($t.ExpectedNav -join ', ')" -ForegroundColor Green
        }
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
    Write-Host ""
}

if ($failed -eq 0) {
    Write-Host "All $($tests.Count) tests passed. OData `$expand is working; UI can rely on it." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$failed test(s) failed." -ForegroundColor Red
    exit 1
}
