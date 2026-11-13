using System.Drawing;

namespace EmberBar;

/// <summary>Short-lived Windows notification: the tray icon exists only while the balloon is shown.</summary>
static class Toast
{
    public static void Show(string text, Action? onClick = null)
    {
        try
        {
            var icon = new NotifyIcon
            {
                Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? "") ?? SystemIcons.Information,
                Visible = true
            };
            var done = new System.Windows.Forms.Timer { Interval = 12000 };
            void Cleanup()
            {
                done.Stop(); done.Dispose();
                icon.Visible = false; icon.Dispose();
            }
            done.Tick += (_, _) => Cleanup();
            icon.BalloonTipClicked += (_, _) => { onClick?.Invoke(); Cleanup(); };
            icon.BalloonTipClosed += (_, _) => Cleanup();
            done.Start();
            icon.ShowBalloonTip(10000, "EmberBar", text, ToolTipIcon.Info);
        }
        catch { }
    }
}
