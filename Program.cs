using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.Win32;

namespace EmberBar;

static class Program
{
    [STAThread]
    static void Main()
    {
        using var mutex = new Mutex(true, "EmberBar.SingleInstance", out bool first);
        if (!first) return;

        var settings = Settings.Load();
        L.Set(settings.Language.Length > 0 ? settings.Language : L.Detect());

        ApplicationConfiguration.Initialize();
        Application.Run(new TrayApp(settings));
    }
}

static class AppInfo
{
    public const string RepoUrl = "https://github.com/canndidojs/emberbar";
    public static string Version => typeof(AppInfo).Assembly.GetName().Version?.ToString(3) ?? "1.0.0";
}

record Usage(double FiveHour, DateTimeOffset? FiveHourResets, double Week, DateTimeOffset? WeekResets);

class TrayApp : ApplicationContext
{
    const string Url = "https://api.anthropic.com/api/oauth/usage";
    const string UsagePage = "https://claude.ai/settings/usage";
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    const string RunName = "EmberBar";

    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(15) };
    static readonly Padding ItemPadding = new(6, 7, 6, 7);
    static readonly int[] Intervals = { 120, 300, 600, 900, 1800 };
    static readonly (string Key, double Factor)[] Sizes = { ("size.small", 0.75), ("size.medium", 0.85), ("size.large", 1.0) };

    readonly Settings _settings;
    readonly TaskbarStrip _strip = new();
    readonly System.Windows.Forms.Timer _timer = new();
    readonly ToolStripLabel _status = new()
    {
        Font = new Font("Segoe UI", 9),
        ForeColor = Color.FromArgb(140, 140, 148),
        Padding = new Padding(8, 0, 8, 8)
    };
    readonly ToolStripMenuItem _refreshItem = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _signItem = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _intervalMenu = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _sizeMenu = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _languageMenu = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _startupItem = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _usageItem = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _aboutItem = new() { Padding = ItemPadding };
    readonly ToolStripMenuItem _quitItem = new() { Padding = ItemPadding };
    readonly List<(ToolStripMenuItem Item, Func<string> Label, Func<bool> Current)> _choices = new();
    Func<(Usage? Usage, string Tip, bool Stale)> _view = () => (null, "", false);
    Usage? _last;
    DateTime _lastAt;
    int _failures;
    bool _busy;

    public TrayApp(Settings settings)
    {
        _settings = settings;
        _strip.SetSize(_settings.SizeFactor);
        _strip.ContextMenuStrip = BuildMenu();

        _timer.Interval = _settings.IntervalSeconds * 1000;
        _timer.Tick += async (_, _) => await RefreshAsync();
        _timer.Start();

        Present(() => (null, L.T("tip.loading"), false));
        if (Auth.SignedIn) _ = RefreshAsync();
        else
        {
            Present(() => (null, L.T("tip.notsignedin"), false));
            var once = new System.Windows.Forms.Timer { Interval = 500 };
            once.Tick += (_, _) => { once.Stop(); once.Dispose(); ShowLogin(); };
            once.Start();
        }
    }

    ContextMenuStrip BuildMenu()
    {
        ToolStripManager.Renderer = new DarkMenuRenderer();
        var menu = new ContextMenuStrip
        {
            Font = new Font("Segoe UI", 10),
            ShowImageMargin = false,
            MinimumSize = new Size(260, 0)
        };

        menu.Items.Add(new ToolStripLabel("EmberBar")
        {
            Font = new Font("Segoe UI Semibold", 11),
            ForeColor = Color.White,
            Padding = new Padding(8, 8, 8, 0)
        });
        menu.Items.Add(_status);
        menu.Items.Add(new ToolStripSeparator());

        _refreshItem.Click += async (_, _) => await RefreshAsync();
        _signItem.Click += (_, _) => SignInOrOut();
        _startupItem.Click += (_, _) => ToggleStartup();
        _usageItem.Click += (_, _) => Open(UsagePage);
        _aboutItem.Click += (_, _) => { using var about = new AboutWindow(); about.ShowDialog(); };
        _quitItem.Click += (_, _) => Quit();

        menu.Items.Add(_refreshItem);
        menu.Items.Add(_signItem);
        menu.Items.Add(new ToolStripSeparator());

        Submenu(_intervalMenu, Intervals.Select(s =>
            ((Func<string>)(() => L.T("interval.minutes", s / 60)),
             (Func<bool>)(() => _settings.IntervalSeconds == s),
             (Action)(() => SetInterval(s)))));
        Submenu(_sizeMenu, Sizes.Select(o =>
            ((Func<string>)(() => L.T(o.Key)),
             (Func<bool>)(() => Math.Abs(_settings.SizeFactor - o.Factor) < 0.001),
             (Action)(() => SetSize(o.Factor)))));
        Submenu(_languageMenu, L.Languages.Select(l =>
            ((Func<string>)(() => l.Name),
             (Func<bool>)(() => L.Code == l.Code),
             (Action)(() => SetLanguage(l.Code)))));
        menu.Items.Add(_intervalMenu);
        menu.Items.Add(_sizeMenu);
        menu.Items.Add(_languageMenu);
        menu.Items.Add(_startupItem);
        menu.Items.Add(new ToolStripSeparator());

        menu.Items.Add(_usageItem);
        menu.Items.Add(_aboutItem);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add(_quitItem);

        ApplyLanguage();
        menu.Opening += (_, _) => ApplyLanguage();

        var watcher = new System.Windows.Forms.Timer { Interval = 50 };
        bool armed = false;
        watcher.Tick += (_, _) =>
        {
            if (Control.MouseButtons == MouseButtons.None) { armed = true; return; }
            if (!armed) return;
            Point p = Cursor.Position;
            bool inside = menu.Bounds.Contains(p)
                || menu.Items.OfType<ToolStripMenuItem>().Any(i => i.DropDown.Visible && i.DropDown.Bounds.Contains(p));
            if (!inside) menu.Close();
        };
        menu.Opened += (_, _) => { armed = false; watcher.Start(); };
        menu.Closed += (_, _) => watcher.Stop();
        return menu;
    }

    void Submenu(ToolStripMenuItem parent, IEnumerable<(Func<string> Label, Func<bool> Current, Action Pick)> options)
    {
        ((ToolStripDropDownMenu)parent.DropDown).ShowImageMargin = false;
        foreach (var (label, current, pick) in options)
        {
            var item = new ToolStripMenuItem { Padding = ItemPadding };
            item.Click += (_, _) => pick();
            _choices.Add((item, label, current));
            parent.DropDownItems.Add(item);
        }
    }

    void ApplyLanguage()
    {
        bool signedIn = Auth.SignedIn;
        _refreshItem.Text = L.T("menu.refresh");
        _signItem.Text = L.T(signedIn ? "menu.signout" : "menu.signin");
        _intervalMenu.Text = L.T("menu.interval");
        _sizeMenu.Text = L.T("menu.size");
        _languageMenu.Text = L.T("menu.language");
        _startupItem.Text = L.T("menu.startup");
        _startupItem.ShortcutKeyDisplayString = L.T(StartupEnabled() ? "on" : "off");
        _usageItem.Text = L.T("menu.usage");
        _aboutItem.Text = L.T("menu.about");
        _quitItem.Text = L.T("menu.quit");
        _status.Text = L.T("menu.status", AppInfo.Version, L.T(signedIn ? "status.signedin" : "status.signedout"));
        foreach (var (item, label, current) in _choices)
        {
            item.Text = label();
            item.ShortcutKeyDisplayString = current() ? "✓" : "";
        }
    }

    void Present(Func<(Usage? Usage, string Tip, bool Stale)> view)
    {
        _view = view;
        Reapply();
    }

    void Reapply()
    {
        var (usage, tip, stale) = _view();
        _strip.SetUsage(usage, tip, stale);
    }

    static void Open(string url)
    {
        try { Process.Start(new ProcessStartInfo(url) { UseShellExecute = true }); }
        catch { }
    }

    void SetInterval(int seconds)
    {
        _settings.IntervalSeconds = seconds;
        _settings.Save();
        _failures = 0;
        _timer.Interval = seconds * 1000;
    }

    void SetSize(double factor)
    {
        _settings.SizeFactor = factor;
        _settings.Save();
        _strip.SetSize(factor);
    }

    void SetLanguage(string code)
    {
        L.Set(code);
        _settings.Language = code;
        _settings.Save();
        ApplyLanguage();
        Reapply();
    }

    void ShowLogin()
    {
        using var window = new LoginWindow();
        if (window.ShowDialog() != DialogResult.OK) return;
        _failures = 0;
        _ = RefreshAsync();
    }

    void SignInOrOut()
    {
        if (!Auth.SignedIn)
        {
            ShowLogin();
            return;
        }
        Auth.SignOut();
        _last = null;
        Present(() => (null, L.T("tip.signedout"), false));
    }

    async Task RefreshAsync()
    {
        if (_busy) return;
        _busy = true;
        try
        {
            var usage = await FetchAsync();
            var at = DateTime.Now;
            _last = usage;
            _lastAt = at;
            _failures = 0;
            Present(() => (usage, Tip(usage, L.T("tip.updated", L.Clock(at))), false));
        }
        catch (Exception ex)
        {
            _failures++;
            string message = ex.Message;
            var usage = _last;
            var at = _lastAt;
            if (usage is null) Present(() => (null, L.T("tip.nodata", message), false));
            else Present(() => (usage, Tip(usage, L.T("tip.stale", L.Clock(at), message)), true));
        }
        finally
        {
            _busy = false;
            int cap = Math.Max(600, _settings.IntervalSeconds);
            _timer.Interval = Math.Min(_settings.IntervalSeconds * (1 << Math.Min(_failures, 5)), cap) * 1000;
        }
    }

    static string Tip(Usage u, string footer) =>
        $"5h: {u.FiveHour:0}%{Resets(u.FiveHourResets, false)}\n" +
        $"{L.T("tip.weekly")}: {u.Week:0}%{Resets(u.WeekResets, true)}\n" +
        footer;

    static string Resets(DateTimeOffset? d, bool withDay) =>
        d is null ? "" : L.T("tip.resets", L.Time(d.Value, withDay));

    static async Task<Usage> FetchAsync()
    {
        string token = await Auth.GetAccessTokenAsync();

        using var req = new HttpRequestMessage(HttpMethod.Get, Url);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        req.Headers.Add("anthropic-beta", "oauth-2025-04-20");
        req.Headers.UserAgent.ParseAdd("EmberBar/" + AppInfo.Version);

        using var resp = await Http.SendAsync(req);
        if (!resp.IsSuccessStatusCode)
            throw new Exception(resp.StatusCode == (HttpStatusCode)429 ? L.T("err.rate") : L.T("err.http", (int)resp.StatusCode));

        using var json = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
        var (five, fiveReset) = Window(json.RootElement, "five_hour");
        var (week, weekReset) = Window(json.RootElement, "seven_day");
        return new Usage(five, fiveReset, week, weekReset);
    }

    static (double, DateTimeOffset?) Window(JsonElement root, string field)
    {
        if (!root.TryGetProperty(field, out var w) || w.ValueKind != JsonValueKind.Object)
            throw new Exception(L.T("err.nofield", field));
        if (!w.TryGetProperty("utilization", out var u) || u.ValueKind != JsonValueKind.Number)
            throw new Exception(L.T("err.badvalue", field));
        DateTimeOffset? resets = null;
        if (w.TryGetProperty("resets_at", out var r) && r.ValueKind == JsonValueKind.String
            && DateTimeOffset.TryParse(r.GetString(), CultureInfo.InvariantCulture, DateTimeStyles.None, out var d))
            resets = d.ToLocalTime();
        return (u.GetDouble(), resets);
    }

    static bool StartupEnabled()
    {
        using var k = Registry.CurrentUser.OpenSubKey(RunKey);
        return k?.GetValue(RunName) is not null;
    }

    static void ToggleStartup()
    {
        using var k = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        if (k is null) return;
        if (k.GetValue(RunName) is null) k.SetValue(RunName, $"\"{Environment.ProcessPath}\"");
        else k.DeleteValue(RunName, throwOnMissingValue: false);
    }

    void Quit()
    {
        _timer.Stop();
        _strip.Close();
        ExitThread();
    }
}
