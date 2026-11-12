using System.Drawing.Drawing2D;

namespace EmberBar;

class MinimalWindow : Form
{
    protected static readonly Color Gray = Color.FromArgb(150, 150, 150);

    protected MinimalWindow(Size size)
    {
        FormBorderStyle = FormBorderStyle.None;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = size;
        BackColor = Color.Black;
        ForeColor = Color.White;
        TopMost = true;
        Text = "EmberBar";
        DoubleBuffered = true;
        KeyPreview = true;
        KeyDown += (_, e) => { if (e.KeyCode == Keys.Escape) Close(); };
        if (AppIcon() is { } icon) Icon = icon;

        var close = AddLabel("✕", new Font("Segoe UI", 11), Gray, new Rectangle(size.Width - 44, 8, 36, 30), ContentAlignment.MiddleCenter);
        close.Cursor = Cursors.Hand;
        close.Click += (_, _) => Close();
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
        var label = new Label { Text = text, Font = font, ForeColor = color, TextAlign = align, Bounds = bounds, BackColor = Color.Transparent };
        Controls.Add(label);
        return label;
    }

    protected Button AddButton(string text, Rectangle bounds, EventHandler onClick)
    {
        var button = new Button
        {
            Text = text,
            Bounds = bounds,
            FlatStyle = FlatStyle.Flat,
            Font = new Font("Segoe UI", 10),
            Cursor = Cursors.Hand
        };
        button.FlatAppearance.BorderColor = Color.White;
        button.FlatAppearance.BorderSize = 1;
        button.FlatAppearance.MouseOverBackColor = Color.White;
        button.FlatAppearance.MouseDownBackColor = Color.FromArgb(220, 220, 220);
        button.Click += onClick;
        button.MouseEnter += (_, _) => StyleButton(button, true);
        button.MouseLeave += (_, _) => StyleButton(button, false);
        StyleButton(button, false);
        Controls.Add(button);
        return button;
    }

    protected static void StyleButton(Button button, bool hover)
    {
        button.BackColor = hover ? Color.White : Color.Black;
        button.ForeColor = hover ? Color.Black : Color.White;
    }

    protected virtual void DrawContent(Graphics g) { }

    protected override void OnPaint(PaintEventArgs e)
    {
        using var border = new Pen(Color.FromArgb(70, 70, 70));
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
