using System.Drawing.Drawing2D;

namespace EmberBar;

/// <summary>Small dark callout shown above the strip while the mouse is over it. Fades and slides in and out.</summary>
class HoverCard : Form
{
    static readonly Color Back = Color.FromArgb(32, 32, 36), Edge = Color.FromArgb(70, 70, 78);
    static readonly Color Main = Color.FromArgb(240, 240, 242), Dim = Color.FromArgb(150, 150, 158);

    readonly System.Windows.Forms.Timer _anim = new() { Interval = 15 };
    string[] _lines = Array.Empty<string>();
    Font? _font, _small;
    Size[] _sizes = Array.Empty<Size>();
    float _target;
    int _restTop;
    int _dpx;

    const TextFormatFlags F = TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix | TextFormatFlags.WordBreak;
    const int PadX = 14, PadY = 10, Gap = 8, MaxText = 420;

    public HoverCard()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        DoubleBuffered = true;
        Opacity = 0;
        BackColor = Back;
        _anim.Tick += (_, _) => Step();
    }

    protected override CreateParams CreateParams
    {
        get { var p = base.CreateParams; p.ExStyle |= 0x80 | 0x08000000; return p; } // tool window, no activate
    }
    protected override bool ShowWithoutActivation => true;

    public bool Shown => Visible && _target > 0;

    public void ShowAbove(string text, Rectangle anchor, int basePx)
    {
        Layout(text, basePx);
        var screen = Screen.FromRectangle(anchor).WorkingArea;
        int x = Math.Clamp(anchor.Left + anchor.Width / 2 - Width / 2, screen.Left + 4, Math.Max(screen.Left + 4, screen.Right - Width - 4));
        _restTop = anchor.Top - Height - Gap;
        if (!Visible)
        {
            Opacity = 0;
            Location = new Point(x, _restTop + 8);
            base.Show();
        }
        else Location = new Point(x, Top);
        _target = 1;
        _anim.Start();
    }

    public void UpdateText(string text, int basePx)
    {
        if (!Shown) return;
        int right = Right, bottom = Bottom;
        Layout(text, basePx);
        Location = new Point(Math.Max(0, right - Width), bottom - Height);
        _restTop = bottom - Height;
    }

    public void Dismiss()
    {
        if (!Visible) return;
        _target = 0;
        _anim.Start();
    }

    void Step()
    {
        double o = Opacity + (_target > Opacity ? 0.14 : -0.12);
        o = _target > Opacity ? Math.Min(o, 1) : Math.Max(o, 0);
        Opacity = o;
        Top = _restTop + (int)((1 - o) * 8);
        if (o == _target)
        {
            _anim.Stop();
            if (_target == 0) Hide();
        }
    }

    void Layout(string text, int basePx)
    {
        _lines = text.Split('\n');
        int px = Math.Max(13, (int)(basePx * 1.1));
        if (px != _dpx || _font is null)
        {
            _dpx = px;
            _font?.Dispose(); _small?.Dispose();
            _font = new Font("Segoe UI", px, FontStyle.Regular, GraphicsUnit.Pixel);
            _small = new Font("Segoe UI", Math.Max(11, px - 2), FontStyle.Regular, GraphicsUnit.Pixel);
        }
        _sizes = _lines.Select((l, i) => TextRenderer.MeasureText(l, FontFor(i), new Size(MaxText, int.MaxValue), F)).ToArray();
        int w = _sizes.Max(s => s.Width) + PadX * 2;
        int lineGap = Math.Max(3, px / 4);
        int h = _sizes.Sum(s => s.Height) + lineGap * (_sizes.Length - 1) + PadY * 2;
        Size = new Size(w, h);
        using var path = Rounded(new Rectangle(0, 0, w, h), 10);
        Region?.Dispose();
        Region = new Region(path);
        Invalidate();
    }

    Font FontFor(int i) => i == _lines.Length - 1 && _lines.Length > 1 ? _small! : _font!;

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (var path = Rounded(new Rectangle(0, 0, Width - 1, Height - 1), 10))
        using (var pen = new Pen(Edge))
            g.DrawPath(pen, path);
        int y = PadY, lineGap = Math.Max(3, _dpx / 4);
        for (int i = 0; i < _lines.Length; i++)
        {
            bool last = i == _lines.Length - 1 && _lines.Length > 1;
            TextRenderer.DrawText(g, _lines[i], FontFor(i), new Rectangle(PadX, y, Width - PadX * 2, _sizes[i].Height),
                last ? Dim : Main, Back, F);
            y += _sizes[i].Height + lineGap;
        }
    }

    static GraphicsPath Rounded(Rectangle r, int radius)
    {
        int d = radius * 2;
        var p = new GraphicsPath();
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { _anim.Dispose(); _font?.Dispose(); _small?.Dispose(); }
        base.Dispose(disposing);
    }
}
