namespace Events.Api.Services;

/// <summary>
/// Reads the build number from <c>buildinfo.txt</c>, which the csproj copies
/// next to the assembly at build time.
/// </summary>
/// <remarks>
/// Read on every call rather than cached: the file is tiny, <c>/healthz</c> is
/// not a hot path, and reading fresh means bumping the number takes effect
/// without needing an API restart.
/// </remarks>
public static class BuildInfo
{
    private const string FileName = "buildinfo.txt";

    /// <summary>
    /// The current build number, or <c>null</c> when the file is missing or
    /// empty. Null is returned rather than throwing so a missing build number
    /// never takes the health endpoint down.
    /// </summary>
    public static string? ReadBuildNumber()
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, FileName);

            if (!File.Exists(path))
            {
                return null;
            }

            var text = File.ReadAllText(path).Trim();

            return string.IsNullOrEmpty(text) ? null : text;
        }
        catch (IOException)
        {
            return null;
        }
        catch (UnauthorizedAccessException)
        {
            return null;
        }
    }
}
