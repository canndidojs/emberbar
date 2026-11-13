using System.Drawing.Drawing2D;

namespace EmberBar;

class HistoryWindow : MinimalWindow
{
    static readonly Color Ember = Color.FromArgb(236, 124, 58), Cool = Color.FromArgb(150, 168, 205);
    static readonly Rectangle Plot = new(64, 160, 452, 190);

    List<MonthUsage> _months = History.Monthly(6);

    public HistoryWindow() : base(new Size(560, 540))
    {
        AddLabel(L.T("hist.title"), new Font("Segoe UI Semibold", 17), Color.White, new Rectangle(0, 30, Width, 34), ContentAlignment.MiddleCenter);
        AddLabel(L.T("hist.sub"), new Font("Segoe UI", 9.5f), Gray, new Rectangle(0, 64, Width, 22), ContentAlignment.MiddleCenter);
        AddLabel(L.T("hist.note"), new Font("Segoe UI", 8.5f), Color.FromArgb(120, 120, 126), new Rectangle(40, 408, 480, 58), ContentAlignment.TopCenter);
        AddButton(L.T("hist.clear"), new Rectangle(40, 480, 170, 40), (_, _) =>
        {
            if (MessageBox.Show(this, L.T("hist.clearask"), "EmberBar", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            History.Clear();
            _months = History.Monthly(6);
            Invalidate();
        }, false);
        AddButton(L.T("about.close"), new Rectangle(428, 480, 92, 40), (_, _) => Close());
    }

    protected override void DrawContent(Graphics g)
    {
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using var small = new Font("Segoe UI", 8.5f);
        using var medium = new Font("Segoe UI", 9.5f);
        const TextFormatFlags C = TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;

        DrawLegend(g, Ember, L.T("hist.five"), 64, 100);
        DrawLegend(g, Cool, L.T("hist.week"), 64, 122);

        using var grid = new Pen(Color.FromArgb(38, 38, 42));
        foreach (int v in new[] { 0, 50, 100 })
        {
            float y = Plot.Bottom - Plot.Height * v / 100f;
            g.DrawLine(grid, Plot.Left, y, Plot.Right, y);
            TextRenderer.DrawText(g, v + "%", small, new Rectangle(Plot.Left - 44, (int)y - 8, 38, 16), Gray,
                TextFormatFlags.Right | TextFormatFlags.NoPadding);
        }

        float group = Plot.Width / (float)_months.Count;
        float bar = group * 0.26f;
        for (int i = 0; i < _months.Count; i++)
        {
            var m = _months[i];
            float cx = Plot.Left + group * (i + 0.5f);
            DrawBar(g, small, m.Avg5, cx - bar - 2, bar, Ember);
            DrawBar(g, small, m.MaxWeek, cx + 2, bar, Cool);

            string name = L.Culture.DateTimeFormat.GetAbbreviatedMonthName(m.Month.Month).TrimEnd('.');
            if (m.Month.Month == 1 || i == 0) name += " " + m.Month.ToString("yy");
            TextRenderer.DrawText(g, name, medium, new Rectangle((int)(cx - group / 2), Plot.Bottom + 8, (int)group, 18), Soft, C);
            TextRenderer.DrawText(g, m.Days == 0 ? "—" : m.Days == 1 ? L.T("hist.day") : L.T("hist.days", m.Days), small,
                new Rectangle((int)(cx - group / 2), Plot.Bottom + 28, (int)group, 16), Gray, C);
        }
    }

    static void DrawLegend(Graphics g, Color c, string text, int x, int y)
    {
        using var b = new SolidBrush(c);
        g.FillRoundedRect(b, new Rectangle(x, y + 4, 10, 10), 3);
        using var f = new Font("Segoe UI", 9);
        TextRenderer.DrawText(g, text, f, new Point(x + 18, y), Soft, TextFormatFlags.NoPadding);
    }

    static void DrawBar(Graphics g, Font small, double? value, float x, float w, Color color)
    {
        if (value is null) return;
        float h = Math.Max(3f, (float)(Math.Min(value.Value, 100) / 100 * Plot.Height));
        var r = Rectangle.Round(new RectangleF(x, Plot.Bottom - h, w, h));
        using var b = new SolidBrush(color);
        g.FillRoundedRect(b, r, 3);
        TextRenderer.DrawText(g, $"{Math.Round(value.Value):0}%", small,
            new Rectangle(r.X - 10, r.Top - 19, r.Width + 20, 15), Soft,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.NoPadding);
    }
}

static class GraphicsExt
{
    /// <summary>Fills a bar with rounded top corners and a flat bottom.</summary>
    public static void FillRoundedRect(this Graphics g, Brush b, Rectangle r, int radius)
    {
        int d = Math.Max(2, Math.Min(radius * 2, Math.Min(r.Width, r.Height)));
        using var p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddLine(r.Right, r.Bottom, r.X, r.Bottom);
        p.CloseFigure();
        g.FillPath(b, p);
    }
}
