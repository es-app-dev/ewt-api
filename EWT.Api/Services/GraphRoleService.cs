using System.Net.Http.Headers;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json;
using Microsoft.Identity.Client;

namespace EWT.Api.Services;

public record EffectiveRoles(string Email, string? ObjectId, string? DisplayName, bool Found, string[] Roles);
public record EwtUser(string ObjectId, string DisplayName, string? Email, string[] Roles);

/// <summary>Thrown when a Microsoft Graph call fails; controllers map this to 502.</summary>
public class GraphRoleException : Exception
{
    public GraphRoleException(string message, Exception? inner = null) : base(message, inner) { }
}

public interface IGraphRoleService
{
    /// <summary>True when a cert + client id + tenant are configured (GraphReader:*). When false, callers fall back to the stub.</summary>
    bool IsConfigured { get; }
    Task<EffectiveRoles> GetEffectiveRolesAsync(string email);
    Task<IReadOnlyList<EwtUser>> GetEwtUsersAsync();
}

/// <summary>
/// Resolves EWT Entra app-roles for a user via Microsoft Graph, app-only (certificate).
/// Reads GraphReader:{ClientId,CertPath,CertPassword,TenantId} + Ewt:ResourceAppId from config
/// (CertPassword must come from user-secrets/env, never source). Singleton: the MSAL app,
/// the resolved service-principal id, and the app-role catalog are cached for the process.
/// </summary>
public class GraphRoleService : IGraphRoleService
{
    private const string GraphBase = "https://graph.microsoft.com/v1.0";
    private static readonly HttpClient Http = new();

    private readonly ILogger<GraphRoleService> _logger;
    private readonly string _tenantId;
    private readonly string _resourceAppId;   // EWT app (bare GUID) whose roles we read
    private readonly string? _clientId;        // GraphReader app the cert belongs to
    private readonly string? _certPath;
    private readonly string? _certPassword;

    private readonly SemaphoreSlim _appLock = new(1, 1);
    private readonly SemaphoreSlim _catalogLock = new(1, 1);
    private readonly SemaphoreSlim _usersLock = new(1, 1);

    private IConfidentialClientApplication? _app;
    private string? _spId;                              // EWT service principal object id (cached)
    private Dictionary<string, string>? _roleCatalog;  // appRoleId -> value (cached)

    private IReadOnlyList<EwtUser>? _usersCache;
    private DateTimeOffset _usersCacheAt;
    private static readonly TimeSpan UsersTtl = TimeSpan.FromMinutes(10);

    public GraphRoleService(IConfiguration cfg, ILogger<GraphRoleService> logger)
    {
        _logger = logger;
        _tenantId = cfg["GraphReader:TenantId"] ?? cfg["AzureAd:TenantId"] ?? "";
        var ewtApp = cfg["Ewt:ResourceAppId"] ?? cfg["AzureAd:ClientId"] ?? "";
        _resourceAppId = ewtApp.Replace("api://", "").Trim();
        _clientId = cfg["GraphReader:ClientId"];
        _certPath = cfg["GraphReader:CertPath"];
        _certPassword = cfg["GraphReader:CertPassword"];
    }

    public bool IsConfigured =>
        !string.IsNullOrWhiteSpace(_clientId) &&
        !string.IsNullOrWhiteSpace(_certPath) && File.Exists(_certPath) &&
        !string.IsNullOrWhiteSpace(_certPassword) &&
        !string.IsNullOrWhiteSpace(_tenantId) &&
        !string.IsNullOrWhiteSpace(_resourceAppId);

    public async Task<EffectiveRoles> GetEffectiveRolesAsync(string email)
    {
        await EnsureCatalogAsync();
        var esc = email.Replace("'", "''");
        var usr = await GetJsonAsync(
            $"{GraphBase}/users?$filter=mail eq '{esc}' or userPrincipalName eq '{esc}'&$select=id,displayName,userPrincipalName,mail");

        var arr = usr.GetProperty("value");
        if (arr.GetArrayLength() == 0)
            return new EffectiveRoles(email, null, null, false, Array.Empty<string>());

        var u = arr[0];
        var uid = u.GetProperty("id").GetString()!;
        var roles = new List<string>();
        foreach (var a in await GetAllAsync($"{GraphBase}/users/{uid}/appRoleAssignments"))
        {
            if (a.GetProperty("resourceId").GetString() != _spId) continue;
            var rid = a.GetProperty("appRoleId").GetString();
            if (rid != null && _roleCatalog!.TryGetValue(rid, out var val)) roles.Add(val);
        }

        return new EffectiveRoles(
            u.GetProperty("userPrincipalName").GetString() ?? email,
            uid,
            u.GetProperty("displayName").GetString(),
            true,
            Sort(roles));
    }

    public async Task<IReadOnlyList<EwtUser>> GetEwtUsersAsync()
    {
        if (_usersCache != null && DateTimeOffset.UtcNow - _usersCacheAt < UsersTtl) return _usersCache;
        await _usersLock.WaitAsync();
        try
        {
            if (_usersCache != null && DateTimeOffset.UtcNow - _usersCacheAt < UsersTtl) return _usersCache;
            await EnsureCatalogAsync();

            // Collapse the (user × role) assignment rows into one entry per principal.
            var byUser = new Dictionary<string, (string Display, string Type, List<string> Roles)>();
            foreach (var a in await GetAllAsync($"{GraphBase}/servicePrincipals/{_spId}/appRoleAssignedTo"))
            {
                var pid = a.GetProperty("principalId").GetString();
                if (pid == null) continue;
                var type = a.TryGetProperty("principalType", out var pt) ? pt.GetString() ?? "" : "";
                var display = a.TryGetProperty("principalDisplayName", out var pd) ? pd.GetString() ?? "" : "";
                if (!byUser.TryGetValue(pid, out var e)) { e = (display, type, new List<string>()); byUser[pid] = e; }
                var rid = a.GetProperty("appRoleId").GetString();
                if (rid != null && _roleCatalog!.TryGetValue(rid, out var val)) e.Roles.Add(val);
            }

            var result = new List<EwtUser>();
            foreach (var (pid, e) in byUser)
            {
                // NOTE: only direct User assignments are listed; group-assigned members are not expanded (see handoff §3).
                if (!string.Equals(e.Type, "User", StringComparison.OrdinalIgnoreCase)) continue;
                string? mail = null;
                try
                {
                    var u = await GetJsonAsync($"{GraphBase}/users/{pid}?$select=userPrincipalName,mail");
                    mail = (u.TryGetProperty("mail", out var m) ? m.GetString() : null)
                           ?? (u.TryGetProperty("userPrincipalName", out var up) ? up.GetString() : null);
                }
                catch { /* best-effort per user */ }
                result.Add(new EwtUser(pid, e.Display, mail, Sort(e.Roles)));
            }

            _usersCache = result.OrderBy(u => u.DisplayName, StringComparer.OrdinalIgnoreCase).ToList();
            _usersCacheAt = DateTimeOffset.UtcNow;
            return _usersCache;
        }
        finally { _usersLock.Release(); }
    }

    // ---- internals ----

    private static string[] Sort(IEnumerable<string> roles) =>
        roles.Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(r => r, StringComparer.OrdinalIgnoreCase).ToArray();

    private async Task<string> TokenAsync()
    {
        if (_app == null)
        {
            await _appLock.WaitAsync();
            try
            {
                if (_app == null)
                {
                    X509Certificate2 cert;
                    try { cert = new X509Certificate2(_certPath!, _certPassword, X509KeyStorageFlags.EphemeralKeySet); }
                    catch (Exception ex) { throw new GraphRoleException("Failed to load GraphReader certificate (pfx/password mismatch?).", ex); }

                    _app = ConfidentialClientApplicationBuilder.Create(_clientId)
                        .WithCertificate(cert)
                        .WithAuthority($"https://login.microsoftonline.com/{_tenantId}")
                        .Build();
                }
            }
            finally { _appLock.Release(); }
        }

        try
        {
            var res = await _app.AcquireTokenForClient(new[] { "https://graph.microsoft.com/.default" }).ExecuteAsync();
            return res.AccessToken;
        }
        catch (Exception ex)
        {
            throw new GraphRoleException("Graph token acquisition failed (client id / cert registration / consent?).", ex);
        }
    }

    private async Task EnsureCatalogAsync()
    {
        if (_spId != null && _roleCatalog != null) return;
        await _catalogLock.WaitAsync();
        try
        {
            if (_spId != null && _roleCatalog != null) return;
            var sp = await GetJsonAsync($"{GraphBase}/servicePrincipals(appId='{_resourceAppId}')?$select=id,appRoles");
            _spId = sp.GetProperty("id").GetString();
            var cat = new Dictionary<string, string>();
            foreach (var ar in sp.GetProperty("appRoles").EnumerateArray())
            {
                var id = ar.GetProperty("id").GetString();
                var val = ar.GetProperty("value").GetString();
                if (id != null && !string.IsNullOrEmpty(val)) cat[id] = val;
            }
            _roleCatalog = cat;
            _logger.LogInformation("GraphRoleService: cached EWT SP {SpId} with {Count} app roles.", _spId, cat.Count);
        }
        finally { _catalogLock.Release(); }
    }

    private async Task<JsonElement> GetJsonAsync(string url)
    {
        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", await TokenAsync());
        using var resp = await Http.SendAsync(req);
        var body = await resp.Content.ReadAsStringAsync();
        if (!resp.IsSuccessStatusCode)
            throw new GraphRoleException($"Graph {(int)resp.StatusCode} on {url}: {body}");
        return JsonDocument.Parse(body).RootElement.Clone();
    }

    private async Task<List<JsonElement>> GetAllAsync(string url)
    {
        var items = new List<JsonElement>();
        string? next = url;
        int guard = 0;
        while (next != null && guard++ < 100)
        {
            var page = await GetJsonAsync(next);
            foreach (var e in page.GetProperty("value").EnumerateArray()) items.Add(e.Clone());
            next = page.TryGetProperty("@odata.nextLink", out var nl) ? nl.GetString() : null;
        }
        return items;
    }
}
