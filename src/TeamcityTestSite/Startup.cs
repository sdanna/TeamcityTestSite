using Microsoft.Owin;
using Owin;

[assembly: OwinStartupAttribute(typeof(TeamcityTestSite.Startup))]
namespace TeamcityTestSite
{
    public partial class Startup
    {
        public void Configuration(IAppBuilder app)
        {
            ConfigureAuth(app);
        }
    }
}
