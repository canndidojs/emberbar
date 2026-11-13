using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace EmberBar;

class TaskbarStrip : Form
{
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string? title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string? title);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr insertAfter, int x, int y, int w, int hgt, uint flags);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [DllImport("gdi32.dll")] static extern uint GetPixel(IntPtr dc, int x, int y);
    [DllImport("shell32.dll")] static extern int SHQueryUserNotificationState(out int state);

    double _sizeFactor = 0.85;
    const uint SWP_NOACTIVATE = 0x10, SWP_SHOWWINDOW = 0x40;
    static readonly IntPtr HWND_TOPMOST = new(-1);

    double? _p5, _pWeek;
    bool _stale;
    Color _background = Color.FromArgb(230, 238, 242);
    Font? _font, _bold;
    int _fontPx;
    readonly ToolTip _tip = new();
    readonly System.Windows.Forms.Timer _timer = new() { Interval = 2000 };

    public TaskbarStrip()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        DoubleBuffered = true;
        _timer.Tick += (_, _) => Reposition();
        _timer.Start();
    }

    protected override CreateParams CreateParams
    {
        get { var p = base.CreateParams; p.ExStyle |= 0x80 | 0x08000000; return p; }
    }
    protected override bool ShowWithoutActivation => true;

    public void SetUsage(Usage? u, string tooltip, bool stale)
    {
        _p5 = u?.FiveHour;
        _pWeek = u?.Week;
        _stale = stale;
        _tip.SetToolTip(this, tooltip);
        Reposition();
        Invalidate();
    }

    public void SetSize(double factor)

    {

        _sizeFactor = factor;

        Reposition();

        Invalidate();

    }


    void Reposition()
    {
        IntPtr bar = FindWindow("Shell_TrayWnd", null);
        if (bar == IntPtr.Zero || !GetWindowRect(bar, out RECT b)
            || (b.Right - b.Left) < (b.Bottom - b.Top) * 2 || FullScreen())
        { if (Visible) Hide(); return; }

        IntPtr tray = FindWindowEx(bar, IntPtr.Zero, "TrayNotifyWnd", null);
        if (tray == IntPtr.Zero || !GetWindowRect(tray, out RECT n)) { if (Visible) Hide(); return; }

        int height = b.Bottom - b.Top - 1; // keep the taskbar's 1px top border visible
        PrepareFonts(height);
        int width = Draw(null, height);
        int x = n.Left - width - 2;

        SampleBackground(x - 4, b.Top + 1 + height / 2);
        if (!Visible) base.Show();
        SetWindowPos(Handle, HWND_TOPMOST, x, b.Top + 1, width, height, SWP_NOACTIVATE | SWP_SHOWWINDOW);
        Invalidate();
    }

    static bool FullScreen() =>
        SHQueryUserNotificationState(out int s) == 0 && s is 2 or 3 or 4;

    void SampleBackground(int x, int y)
    {
        IntPtr dc = GetDC(IntPtr.Zero);
        uint c = GetPixel(dc, x, y);
        ReleaseDC(IntPtr.Zero, dc);
        if (c == 0xFFFFFFFF) return;
        var color = Color.FromArgb((int)(c & 0xFF), (int)((c >> 8) & 0xFF), (int)((c >> 16) & 0xFF));
        if (color != _background) { _background = color; Invalidate(); }
    }

    void PrepareFonts(int barHeight)
    {
        int px = Math.Max(10, (int)(barHeight * 0.34 * _sizeFactor));
        if (px == _fontPx) return;
        _fontPx = px;
        _font?.Dispose(); _bold?.Dispose();
        _font = new Font("Segoe UI", px, FontStyle.Regular, GraphicsUnit.Pixel);
        _bold = new Font("Segoe UI", px, FontStyle.Bold, GraphicsUnit.Pixel);
    }

    protected override void OnPaint(PaintEventArgs e) => Draw(e.Graphics, Height);

    int Draw(Graphics? g, int height)
    {
        if (_font is null || _bold is null) return 0;
        double k = height * _sizeFactor;
        bool light = _background.GetBrightness() > 0.6f;
        Color text = light ? Color.FromArgb(30, 30, 30) : Color.FromArgb(245, 245, 245);
        Color gray = light ? Color.FromArgb(105, 105, 105) : Color.FromArgb(175, 175, 175);

        using var measurer = g is null ? CreateGraphics() : null;
        var gr = g ?? measurer!;
        if (g is not null) { g.Clear(_background); g.SmoothingMode = SmoothingMode.AntiAlias; }

        const TextFormatFlags F = TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;
        int x = (int)(k * 0.22);
        void Text(string s, Font f, Color c)
        {
            Size t = TextRenderer.MeasureText(gr, s, f, new Size(int.MaxValue, int.MaxValue), F);
            if (g is not null) TextRenderer.DrawText(g, s, f, new Point(x, (height - t.Height) / 2), c, _background, F);
            x += t.Width;
        }

        float r = (float)k * 0.28f;
        if (g is not null && Mark is not null)
        {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.DrawImage(Mark, x, height / 2f - r, r * 2, r * 2);
        }
        x += (int)(r * 2 + k * 0.16);

        Text("5h", _font, gray);   x += (int)(k * 0.12);
        Text(Pct(_p5), _bold, _stale ? gray : ValueColor(_p5, text));
        x += (int)(k * 0.28);

        if (g is not null) { using var pen = new Pen(Color.FromArgb(90, gray)); g.DrawLine(pen, x, height / 2f - (float)k * 0.22f, x, height / 2f + (float)k * 0.22f); }
        x += (int)(k * 0.28);

        Text(L.T("strip.week"), _font, gray);    x += (int)(k * 0.12);
        Text(Pct(_pWeek), _bold, _stale ? gray : ValueColor(_pWeek, text));
        return x + (int)(k * 0.22);
    }

    static string Pct(double? p) => p is null ? "--" : $"{Math.Round(p.Value):0}%";

    static Color ValueColor(double? p, Color normal) =>
        p >= 90 ? Color.FromArgb(205, 45, 45) : p >= 70 ? Color.FromArgb(205, 110, 40) : normal;

    internal static readonly Image? Mark = LoadImage("EmberBar.app-mark.png");
    static Image? LoadImage(string resource)
    {
        using var s = typeof(TaskbarStrip).Assembly.GetManifestResourceStream(resource);
        return s is null ? null : new Bitmap(s);
    }
    protected override void Dispose(bool disposing)
    {
        if (disposing) { _timer.Dispose(); _tip.Dispose(); _font?.Dispose(); _bold?.Dispose(); }
        base.Dispose(disposing);
    }
}
