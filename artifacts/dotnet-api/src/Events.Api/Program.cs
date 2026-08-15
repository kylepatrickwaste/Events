using Microsoft.Data.SqlClient;
using Serilog;
using System.Data;
using Events.Api.Services;

// Bootstrap logger before host builds
Log.Logger = new LoggerConfiguration()
    .WriteTo.Console()
    .CreateBootstrapLogger();

try
{
    var builder = WebApplication.CreateBuilder(args);

    // Serilog
    builder.Host.UseSerilog((ctx, cfg) =>
        cfg.ReadFrom.Configuration(ctx.Configuration)
           .Enrich.FromLogContext()
           .WriteTo.Console());

    // CORS – allow any origin (same as existing Express API)
    builder.Services.AddCors(opts =>
        opts.AddDefaultPolicy(p =>
            p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));

    // SQL connection factory
    builder.Services.AddScoped<IDbConnection>(_ =>
    {
        var cs = builder.Configuration.GetConnectionString("Default")
            ?? throw new InvalidOperationException("ConnectionStrings:Default is required.");
        return new SqlConnection(cs);
    });

    // Repository / services
    builder.Services.AddScoped<EventsRepository>();

    builder.Services.AddControllers()
        .AddJsonOptions(o =>
        {
            o.JsonSerializerOptions.DefaultIgnoreCondition =
                System.Text.Json.Serialization.JsonIgnoreCondition.Never;
            o.JsonSerializerOptions.PropertyNamingPolicy =
                System.Text.Json.JsonNamingPolicy.CamelCase;
        });

    var app = builder.Build();

    // Create tables and seed data on startup (idempotent)
    var cs = builder.Configuration.GetConnectionString("Default")
        ?? throw new InvalidOperationException("ConnectionStrings:Default is required.");
    await DatabaseInitializer.InitializeAsync(cs);

    app.UseSerilogRequestLogging();
    app.UseCors();

    // All routes live under /api
    app.MapControllers();

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}
