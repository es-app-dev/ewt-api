using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using EWT.Api.Services;
using EWT.Services.Utilites;

namespace EWT.Api.Controllers;

/// <summary>
/// Dev/test impersonation endpoints from docs/API-HANDOFF-Impersonation.md.
/// When GraphReader:* is configured, roles come LIVE from Microsoft Graph (app-only cert).
/// Otherwise it falls back to canned personas (DevImpersonation:Users / built-ins) so the UI
/// can exercise the role gates before Graph creds/consent are in place. The response header
/// X-EWT-Source ("graph"|"stub") says which path served the request.
///
/// [AllowAnonymous] so it works locally without a token. The real deployment should require a
/// bearer token (handoff section 1). Gated by DevImpersonation:Enabled (default FALSE, fail-closed):
/// enable only in dev/test.
/// </summary>
[ApiController]
[Route("api/dev")]
[AllowAnonymous]
public class DevImpersonationController : ControllerBase
{
    private readonly IConfiguration _config;
    private readonly IGraphRoleService _graph;
    private readonly ILogger<DevImpersonationController> _logger;

    public DevImpersonationController(IConfiguration config, IGraphRoleService graph, ILogger<DevImpersonationController> logger)
    {
        _config = config;
        _graph = graph;
        _logger = logger;
    }

    private sealed record StubUser(string Email, string ObjectId, string DisplayName, string[] Roles);

    // Built-in personas so it works with zero config. Override/extend via DevImpersonation:Users.
    private static readonly StubUser[] BuiltIn =
    {
        new("brchaffins@energysolutions.com", "stub-brchaffins-0001", "Bruce Chaffins", new[] { "User", "Admin" }),
        new("testadmin@energysolutions.com",  "stub-admin-0002",      "Test Admin",     new[] { "Admin" }),
        new("testuser@energysolutions.com",   "stub-user-0003",       "Test User",      new[] { "User" }),
        new("norole@energysolutions.com",     "stub-norole-0004",     "No Role",        Array.Empty<string>()),
    };

    private bool Enabled => _config.GetValue("DevImpersonation:Enabled", false);

    /// <summary>Built-in personas overlaid with any configured DevImpersonation:Users (config wins by email).</summary>
    private IReadOnlyDictionary<string, StubUser> Users()
    {
        var map = new Dictionary<string, StubUser>(StringComparer.OrdinalIgnoreCase);
        foreach (var u in BuiltIn) map[u.Email] = u;

        var configured = _config.GetSection("DevImpersonation:Users").Get<List<StubUser>>();
        if (configured != null)
            foreach (var u in configured.Where(u => !string.IsNullOrWhiteSpace(u.Email)))
                map[u.Email] = u;

        return map;
    }

    private IActionResult? GuardDisabled()
    {
        if (Enabled) return null;
        _logger.LogWarning("DevImpersonation endpoint hit while disabled, returning 404 (fail-closed).");
        return NotFound();
    }

    /// <summary>Effective Entra roles for one user: live from Graph, or canned when Graph is not configured.</summary>
    [HttpGet("effective-roles")]
    public async Task<IActionResult> EffectiveRoles([FromQuery] string? email)
    {
        if (GuardDisabled() is { } blocked) return blocked;
        if (string.IsNullOrWhiteSpace(email))
            return BadRequest(new { error = new { message = "email query parameter is required" } });

        var caller = UserContextHelper.GetUserName();
        var source = _graph.IsConfigured ? "graph" : "stub";
        Response.Headers["X-EWT-Source"] = source;
        if (source == "stub") Response.Headers["X-EWT-Stub"] = "true";
        _logger.LogInformation("effective-roles [{Source}]: caller='{Caller}' email='{Email}' at {Ts:o}",
            source, string.IsNullOrEmpty(caller) ? "(anonymous)" : caller, email, DateTime.UtcNow);

        if (_graph.IsConfigured)
        {
            try
            {
                var r = await _graph.GetEffectiveRolesAsync(email);
                return Ok(new { email = r.Email, objectId = r.ObjectId, displayName = r.DisplayName, found = r.Found, roles = r.Roles });
            }
            catch (GraphRoleException ex)
            {
                _logger.LogError(ex, "Graph role lookup failed for {Email}", email);
                return StatusCode(502, new { error = new { message = "Graph lookup failed", details = ex.Message } });
            }
        }

        // stub fallback
        if (Users().TryGetValue(email, out var u))
            return Ok(new { email = u.Email, objectId = u.ObjectId, displayName = u.DisplayName, found = true, roles = u.Roles });
        return Ok(new { email, objectId = (string?)null, displayName = (string?)null, found = false, roles = Array.Empty<string>() });
    }

    /// <summary>Users for the impersonation picker: live from Graph, or canned when Graph is not configured.</summary>
    [HttpGet("ewt-users")]
    public async Task<IActionResult> EwtUsers()
    {
        if (GuardDisabled() is { } blocked) return blocked;

        var source = _graph.IsConfigured ? "graph" : "stub";
        Response.Headers["X-EWT-Source"] = source;
        if (source == "stub") Response.Headers["X-EWT-Stub"] = "true";
        _logger.LogInformation("ewt-users [{Source}] requested by '{Caller}' at {Ts:o}",
            source, UserContextHelper.GetUserName() is { Length: > 0 } c ? c : "(anonymous)", DateTime.UtcNow);

        if (_graph.IsConfigured)
        {
            try
            {
                var users = await _graph.GetEwtUsersAsync();
                return Ok(users.Select(u => new { objectId = u.ObjectId, displayName = u.DisplayName, email = u.Email, roles = u.Roles }));
            }
            catch (GraphRoleException ex)
            {
                _logger.LogError(ex, "Graph ewt-users lookup failed");
                return StatusCode(502, new { error = new { message = "Graph lookup failed", details = ex.Message } });
            }
        }

        // stub fallback
        var list = Users().Values
            .OrderBy(u => u.DisplayName)
            .Select(u => new { objectId = u.ObjectId, displayName = u.DisplayName, email = u.Email, roles = u.Roles });
        return Ok(list);
    }
}
