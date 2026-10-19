using Microsoft.AspNetCore.Http;
using System.Security.Claims;

namespace EWT.Services.Utilites
{
    public static class UserContextHelper
    {
        private static IHttpContextAccessor? _httpContextAccessor;

        public static void Configure(IHttpContextAccessor httpContextAccessor)
        {
            _httpContextAccessor = httpContextAccessor;
        }

        public static ClaimsPrincipal? GetUser()
        {
            return _httpContextAccessor?.HttpContext?.User;
        }

        public static string GetUserName()
        {
            return GetUser()?.FindFirst(ClaimTypes.Name)?.Value ?? String.Empty;
        }

        /// <summary>
        /// Entra object id (oid) of the caller, from the validated JWT.
        /// Empty when no token is present (e.g. auth disabled / anonymous call).
        /// </summary>
        public static string GetUserOid()
        {
            var user = GetUser();
            return user?.FindFirst("oid")?.Value
                ?? user?.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier")?.Value
                ?? String.Empty;
        }

        public static List<string>? GetUserRoles()
        {
            return _httpContextAccessor?.HttpContext?.User.Claims
                      .Where(c => c.Type == ClaimTypes.Role)
                      .Select(c => c.Value)
                      .ToList();
        }
    }

}