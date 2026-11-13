using System.Globalization;
using System.Text.Json;

namespace EmberBar;

/// <summary>One day of usage: the highest 5-hour and weekly percentages seen that day.</summary>
record DayUsage(string Day, double Peak5, double PeakWeek);

record MonthUsage(DateTime Month, int Days, double? Avg5, double? MaxWeek);

/// <summary>Daily usage peaks kept on this PC (%APPDATA%\EmberBar\history.json). The API offers no history, so it starts when the app starts recording.</summary>
static class History
{
    const int KeepDays = 200;
    static readonly string FilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "EmberBar", "history.json");
    static List<DayUsage>? _days;

    static List<DayUsage> Days => _days ??= Load();

    static List<DayUsage> Load()
    {
        try { return JsonSerializer.Deserialize<List<DayUsage>>(File.ReadAllText(FilePath)) ?? new(); }
        catch { return new(); }
    }

    static void Save()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(Days));
        }
        catch { }
    }

    public static void Record(Usage u)
    {
        string today = DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        var days = Days;
        int i = days.FindIndex(d => d.Day == today);
        var merged = i < 0
            ? new DayUsage(today, u.FiveHour, u.Week)
            : new DayUsage(today, Math.Max(days[i].Peak5, u.FiveHour), Math.Max(days[i].PeakWeek, u.Week));
        if (i < 0) days.Add(merged); else days[i] = merged;

        string cutoff = DateTime.Now.AddDays(-KeepDays).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
        days.RemoveAll(d => string.CompareOrdinal(d.Day, cutoff) < 0);
        Save();
    }

    public static void Clear()
    {
        Days.Clear();
        try { File.Delete(FilePath); } catch { }
    }

    /// <summary>The last <paramref name="months"/> months, oldest first, ending with the current one.</summary>
    public static List<MonthUsage> Monthly(int months)
    {
        var first = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1);
        var result = new List<MonthUsage>();
        for (int k = months - 1; k >= 0; k--)
        {
            var m = first.AddMonths(-k);
            string prefix = m.ToString("yyyy-MM", CultureInfo.InvariantCulture);
            var inMonth = Days.Where(d => d.Day.StartsWith(prefix, StringComparison.Ordinal)).ToList();
            result.Add(inMonth.Count == 0
                ? new MonthUsage(m, 0, null, null)
                : new MonthUsage(m, inMonth.Count, inMonth.Average(d => d.Peak5), inMonth.Max(d => d.PeakWeek)));
        }
        return result;
    }
}
