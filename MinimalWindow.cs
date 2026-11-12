using System.Drawing.Drawing2D;

namespace EmberBar;

class FlatButton : Control
{
    static readonly Color Hover = Color.FromArgb(42, 42, 47);
    static readonly Color Line = Color.FromArgb(70, 70, 76);
    static readonly Color Bright = Color.FromArgb(244, 244, 246);

    readonly System.Windows.Forms.Timer _timer = new() { Interval = 15 };
    bool _hover, _down;
    float _t;

    public bool Primary { get; set; } = true;

    public FlatButton()
    {
        SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        Cursor = Cursors.Hand;
        Font = new Font("Segoe UI Semibold", 9.5f);
        _timer.Tick += (_, _) =>
        {
            float target = _hover ? 1f : 0f;
            _t += Math.Sign(target - _t) * 0.25f;
            if (Math.Abs(target - _t) < 0.01f) { _t = target; _timer.Stop(); }
            Invalidate();
        };
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _timer.Dispose();
        base.Dispose(disposing);
    }

    protected override void OnMouseEnter(EventArgs e) { _hover = true; _timer.Start(); base.OnMouseEnter(e); }
    protected override void OnMouseLeave(EventArgs e) { _hover = false; _down = false; _timer.Start(); base.OnMouseLeave(e); }
    protected override void OnMouseDown(MouseEventArgs e) { _down = true; Invalidate(); base.OnMouseDown(e); }
    protected override void OnMouseUp(MouseEventArgs e) { _down = false; Invalidate(); base.OnMouseUp(e); }
    protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

    static Color Mix(Color a, Color b, float t) => Color.FromArgb(
        (int)(a.R + (b.R - a.R) * t), (int)(a.G + (b.G - a.G) * t), (int)(a.B + (b.B - a.B) * t));

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        var back = Parent?.BackColor ?? Color.Black;
        g.Clear(back);
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.PixelOffsetMode = PixelOffsetMode.Half;
        using var path = Rounded(new Rectangle(0, 0, Width - 1, Height - 1), 8);

        Color fillColor, text;
        if (Primary)
        {
            fillColor = _down ? Color.FromArgb(196, 196, 200) : Mix(Bright, Color.FromArgb(222, 222, 226), _t);
            text = Color.FromArgb(18, 18, 20);
        }
        else
        {
            fillColor = _down ? Color.FromArgb(52, 52, 58) : Mix(back, Hover, _t);
            text = Color.FromArgb(236, 236, 236);
        }

        using (var fill = new SolidBrush(fillColor)) g.FillPath(fill, path);
        if (!Primary)
        {
            using var pen = new Pen(Mix(Line, Color.FromArgb(104, 104, 112), _t));
            g.DrawPath(pen, path);
        }

        TextRenderer.DrawText(g, Text, Font, new Rectangle(0, 0, Width, Height), text, fillColor,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.NoPadding | TextFormatFlags.EndEllipsis);
    }

    static GraphicsPath Rounded(Rectangle r, int radius)
    {
        int d = radius * 2;
        var path = new GraphicsPath();
        path.AddArc(r.X, r.Y, d, d, 180, 90);
        path.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        path.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        path.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }
}

class MinimalWindow : Form
{
    protected static readonly Color Surface = Color.Black;
    protected static readonly Color Edge = Color.FromArgb(70, 70, 70);
    protected static readonly Color Gray = Color.FromArgb(150, 150, 156);
    protected static readonly Color Soft = Color.FromArgb(214, 214, 218);

    protected MinimalWindow(Size size)
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = size;
        BackColor = Surface;
        ForeColor = Color.White;
        TopMost = true;
        Text = "EmberBar";
        DoubleBuffered = true;
        KeyPreview = true;
        KeyDown += (_, e) => { if (e.KeyCode == Keys.Escape) Close(); };
        if (AppIcon() is { } icon) Icon = icon;

        var close = AddLabel("✕", new Font("Segoe UI", 10), Gray, new Rectangle(size.Width - 40, 8, 32, 28), ContentAlignment.MiddleCenter);
        close.Cursor = Cursors.Hand;
        close.Click += (_, _) => Close();
        close.MouseEnter += (_, _) => close.ForeColor = Color.White;
        close.MouseLeave += (_, _) => close.ForeColor = Gray;
    }

    protected static Icon? AppIcon(int? size = null)
    {
        try
        {
            using var stream = typeof(MinimalWindow).Assembly.GetManifestResourceStream("EmberBar.app.ico");
            if (stream is null) return null;
            return size is { } n ? new Icon(stream, n, n) : new Icon(stream);
        }
        catch { return null; }
    }

    protected Label AddLabel(string text, Font font, Color color, Rectangle bounds, ContentAlignment align)
    {
        var label = new Label { Text = text, Font = font, ForeColor = color, TextAlign = align, Bounds = bounds, BackColor = Color.Transparent, AutoSize = false };
        Controls.Add(label);
        return label;
    }

    protected FlatButton AddButton(string text, Rectangle bounds, EventHandler onClick, bool primary = true)
    {
        var button = new FlatButton { Text = text, Bounds = bounds, Primary = primary };
        button.Click += onClick;
        Controls.Add(button);
        return button;
    }

    protected virtual void DrawContent(Graphics g) { }

    protected override void OnPaint(PaintEventArgs e)
    {
        using var border = new Pen(Edge);
        e.Graphics.DrawRectangle(border, 0, 0, Width - 1, Height - 1);
        DrawContent(e.Graphics);
    }

    protected override void WndProc(ref Message m)
    {
        const int WM_NCHITTEST = 0x84, HTCLIENT = 1, HTCAPTION = 2;
        base.WndProc(ref m);
        if (m.Msg == WM_NCHITTEST && (int)m.Result == HTCLIENT) m.Result = HTCAPTION;
    }
}
