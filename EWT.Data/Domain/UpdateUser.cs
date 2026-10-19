using EWT.Data.Models;

namespace EWT.Data.Domain
{
    public class UpdateUser
    {
        public required EwtUserEntity User { get; set; }
        public List<UserRole>? Roles { get; set; }
    }
}
