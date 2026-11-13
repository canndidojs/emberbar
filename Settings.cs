using System.Text.Json;

namespace EmberBar;

class Settings
{
    static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "EmberBar", "settings.json");

    public int IntervalSeconds { get; set; } = 300;
    public double SizeFactor { get; set; } = 0.85;
    public string Language { get; set; } = "";
    public bool ShowReset { get; set; } = true;
    public bool Notify { get; set; } = true;

    public static Settings Load()
    {
        try
        {
            var s = JsonSerializer.Deserialize<Settings>(File.ReadAllText(FilePath)) ?? new Settings();
            s.IntervalSeconds = Math.Clamp(s.IntervalSeconds, 15, 3600);
            s.SizeFactor = Math.Clamp(s.SizeFactor, 0.5, 1.5);
            s.Language ??= "";
            return s;
        }
        catch { return new Settings(); }
    }

    public void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(this));
        }
        catch { }
    }
}
