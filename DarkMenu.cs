using System.Drawing.Drawing2D;

namespace EmberBar;

class DarkMenuRenderer : ToolStripProfessionalRenderer
{
    static readonly Color Back = Color.FromArgb(18, 18, 20);
    static readonly Color Hover = Color.FromArgb(42, 42, 47);
    static readonly Color Line = Color.FromArgb(58, 58, 64);
    static readonly Color Text = Color.FromArgb(236, 236, 236);
    static readonly Color Dim = Color.FromArgb(140, 140, 148);

    public DarkMenuRenderer() : base(new ProfessionalColorTable()) { RoundedEdges = false; }

    protected override void OnRenderToolStripBackground(ToolStripRenderEventArgs e) => e.Graphics.Clear(Back);

    protected override void OnRenderToolStripBorder(ToolStripRenderEventArgs e)
    {
        using var pen = new Pen(Line);
        e.Graphics.DrawRectangle(pen, 0, 0, e.ToolStrip.Width - 1, e.ToolStrip.Height - 1);
    }

    protected override void OnRenderImageMargin(ToolStripRenderEventArgs e) { }

    protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
    {
        if (!e.Item.Selected || !e.Item.Enabled) return;
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        using var path = Rounded(new Rectangle(4, 1, e.Item.Width - 9, e.Item.Height - 3), 6);
        using var brush = new SolidBrush(Hover);
        e.Graphics.FillPath(brush, path);
    }

    protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
    {
        if (e.Item is ToolStripMenuItem item)
        {
            bool isHint = item.ShortcutKeyDisplayString is { Length: > 0 } hint && hint == e.Text;
            e.TextColor = !item.Enabled || isHint ? Dim : Text;
        }
        base.OnRenderItemText(e);
    }

    protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
    {
        using var pen = new Pen(Line);
        int y = e.Item.Height / 2;
        e.Graphics.DrawLine(pen, 12, y, e.Item.Width - 12, y);
    }

    protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e)
    {
        e.ArrowColor = Dim;
        base.OnRenderArrow(e);
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
