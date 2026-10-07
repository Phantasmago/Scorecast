using System.Text.Json;
using System.Text.Json.Serialization;
using ScoreCast.Contracts;
using ScoreCast.Server.Ingestion;
using ScoreCast.Server.Push;
using ScoreCast.Server.Sync;

var builder = WebApplication.CreateBuilder(args);

// --- JSON: camelCase + string enums, matching the contract wire format ---------
builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    o.SerializerOptions.Converters.Add(new JsonStringEnumConverter());
    o.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});

// --- Options -------------------------------------------------------------------
var syncOpts = builder.Configuration.GetSection("Sync").Get<SyncOptions>() ?? new SyncOptions();
builder.Services.AddSingleton(syncOpts);

// --- HttpClient for football-data.org with the auth header baked in ------------
builder.Services.AddHttpClient(nameof(FootballDataOrgSource), (sp, c) =>
{
    var cfg = sp.GetRequiredService<IConfiguration>();
    c.BaseAddress = new Uri("https://api.football-data.org/v4/");
    c.DefaultRequestHeaders.Add("X-Auth-Token", cfg["Sources:FootballDataOrg:ApiKey"] ?? "");
    c.Timeout = TimeSpan.FromSeconds(15);
});

// --- Ingestion sources (register more adapters here as you add free sources) ---
builder.Services.AddSingleton<ISportsSource, FootballDataOrgSource>();
builder.Services.AddSingleton<SportsSourceRegistry>();

// --- Core services -------------------------------------------------------------
builder.Services.AddSingleton<MatchCache>();
builder.Services.AddSingleton<IFcmPushService, FcmPushService>();
builder.Services.AddHostedService<SyncHostedService>();

var app = builder.Build();

// === REST API consumed by the Flutter app ======================================
// The app pulls a snapshot on launch / pull-to-refresh; between pulls it's driven
// by FCM. The widget never calls these — it reads DataStore the app writes.

app.MapGet("/api/health", () => Results.Ok(new { status = "ok", at = DateTimeOffset.UtcNow }));

// GET /api/matches?status=live&sport=Football&league=PL  (all params optional)
app.MapGet("/api/matches", (MatchCache cache, string? status, string? sport, string? league) =>
{
    Sport? sportFilter = Enum.TryParse<Sport>(sport, true, out var s) ? s : null;
    MatchStatus? statusFilter = Enum.TryParse<MatchStatus>(status, true, out var st) ? st : null;
    return Results.Ok(cache.Query(sportFilter, statusFilter, league));
});

// GET /api/matches/{id}  -> single match (deep-link / details prefetch)
app.MapGet("/api/matches/{id}", (MatchCache cache, string id) =>
{
    var m = cache.TryGet(id);
    return m is null ? Results.NotFound() : Results.Ok(m);
});

app.Run();
