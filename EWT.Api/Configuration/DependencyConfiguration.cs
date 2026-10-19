using EWT.Data;
using EWT.Data.Interfaces;
using EWT.Data.Repositories;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;

namespace EWT.Api.Configuration
{
    public static class DependencyConfiguration
    {
        public static IServiceCollection AddDependencyConfiguration(this IServiceCollection services)
        {
            services.AddScoped<EwtContext, EwtContext>();
            services.AddScoped<IGenericRepository, GenericRepository>();
            return services;
        }

        public static IServiceCollection AddAuthenticationConfiguration(this IServiceCollection services, IConfiguration configuration)
        {
            var tenantId = configuration["AzureAd:TenantId"];
            var clientId = configuration["AzureAd:ClientId"];

            services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
                .AddJwtBearer(options =>
                {
                    options.Authority = $"https://login.microsoftonline.com/{tenantId}/v2.0";
                    options.Audience = $"{clientId}";
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidIssuers =
                        [
                            $"https://login.microsoftonline.com/{tenantId}/v2.0",
                            $"https://sts.windows.net/{tenantId}/"
                        ],
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        RoleClaimType = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role" // Use Azure AD's role claim type
                    };
                });

            services.AddAuthorization(options =>
            {
                //options.AddPolicy("Admin", policy => policy.RequireRole("Admin"));
                options.AddPolicy("User", policy => policy.RequireRole("User"));
                // Add other policies if needed
            });

            return services;
        }

    }
}
