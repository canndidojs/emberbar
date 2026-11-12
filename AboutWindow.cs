using System.Diagnostics;

namespace EmberBar;

class AboutWindow : MinimalWindow
{
    readonly Image? _icon = AppIcon(64)?.ToBitmap();

    public AboutWindow() : base(new Size(400, 500))
    {
        AddLabel("EmberBar", new Font("Segoe UI Semibold", 18), Color.White, new Rectangle(0, 116, Width, 36), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.version", AppInfo.Version), new Font("Segoe UI", 9.5f), Gray, new Rectangle(0, 152, Width, 24), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.desc"), new Font("Segoe UI", 10.5f), Soft, new Rectangle(32, 194, 336, 72), ContentAlignment.TopCenter);
        AddLabel(L.T("about.author"), new Font("Segoe UI", 10), Gray, new Rectangle(40, 296, 320, 24), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.star"), new Font("Segoe UI", 10), Soft, new Rectangle(40, 324, 320, 24), ContentAlignment.MiddleCenter);
        AddLabel(L.T("about.trademark"), new Font("Segoe UI", 8.5f), Color.FromArgb(110, 110, 116), new Rectangle(40, 430, 320, 48), ContentAlignment.TopCenter);

        if (AppInfo.RepoUrl.Length > 0)
        {
            AddButton(L.T("about.starbutton"), new Rectangle(48, 368, 200, 40), (_, _) => Process.Start(new ProcessStartInfo(AppInfo.RepoUrl) { UseShellExecute = true }));
            AddButton(L.T("about.close"), new Rectangle(260, 368, 92, 40), (_, _) => Close(), false);
        }
        else AddButton(L.T("about.close"), new Rectangle(150, 368, 100, 40), (_, _) => Close(), false);
    }

    protected override void DrawContent(Graphics g)
    {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        if (_icon is not null) g.DrawImage(_icon, Width / 2 - 32, 40, 64, 64);
        using var line = new Pen(Edge);
        g.DrawLine(line, 40, 280, Width - 40, 280);
    }
}
