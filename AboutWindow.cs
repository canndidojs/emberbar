using System.Diagnostics;

namespace EmberBar;

class AboutWindow : MinimalWindow
{
    readonly Image? _icon = AppIcon(64)?.ToBitmap();

    public AboutWindow() : base(new Size(420, 500))
    {
        AddLabel("EmberBar", new Font("Segoe UI Light", 22), Color.White, new Rectangle(0, 112, Width, 44), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.version", AppInfo.Version), new Font("Segoe UI", 10), Gray, new Rectangle(0, 156, Width, 24), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.desc"), new Font("Segoe UI", 10), Color.FromArgb(210, 210, 210), new Rectangle(40, 200, 340, 44), ContentAlignment.TopCenter);
        AddLabel(L.T("about.author"), new Font("Segoe UI", 10), Gray, new Rectangle(40, 252, 340, 48), ContentAlignment.TopCenter);
        AddLabel(L.T("about.star"), new Font("Segoe UI Semibold", 10), Color.White, new Rectangle(40, 316, 340, 24), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.trademark"), new Font("Segoe UI", 8), Color.FromArgb(105, 105, 105), new Rectangle(40, 436, 340, 48), ContentAlignment.TopCenter);

        if (AppInfo.RepoUrl.Length > 0)
        {
            AddButton(L.T("about.starbutton"), new Rectangle(60, 356, 190, 40), (_, _) => Process.Start(new ProcessStartInfo(AppInfo.RepoUrl) { UseShellExecute = true }));
            AddButton(L.T("about.close"), new Rectangle(262, 356, 100, 40), (_, _) => Close());
        }
        else AddButton(L.T("about.close"), new Rectangle(160, 356, 100, 40), (_, _) => Close());
    }

    protected override void DrawContent(Graphics g)
    {
        if (_icon is not null) g.DrawImage(_icon, Width / 2 - 32, 36, 64, 64);
    }
}
