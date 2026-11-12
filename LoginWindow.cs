namespace EmberBar;

class LoginWindow : MinimalWindow
{
    readonly Label _message;
    readonly Button _button;
    CancellationTokenSource? _cts;

    public LoginWindow() : base(new Size(380, 290))
    {
        AddLabel("EmberBar", new Font("Segoe UI Light", 22), Color.White, new Rectangle(0, 100, Width, 44), ContentAlignment.MiddleCenter);
        _message = AddLabel("", new Font("Segoe UI", 10), Gray, new Rectangle(40, 152, 300, 56), ContentAlignment.TopCenter);
        _button = AddButton("", new Rectangle(70, 222, 240, 40), OnButtonClick);
        SetState(L.T("login.intro"), L.T("login.button"));
    }

    void SetState(string message, string? button)
    {
        _message.Text = message;
        _button.Visible = button is not null;
        if (button is not null) _button.Text = button;
        StyleButton(_button, false);
    }

    async void OnButtonClick(object? sender, EventArgs e)
    {
        if (_cts is not null)
        {
            _cts.Cancel();
            return;
        }

        _cts = new CancellationTokenSource(TimeSpan.FromMinutes(3));
        SetState(L.T("login.waiting"), L.T("login.cancel"));
        try
        {
            await Auth.LoginAsync(_cts.Token);
            if (IsDisposed) return;
            SetState(L.T("login.done"), null);
            await Task.Delay(3000);
            if (!IsDisposed) DialogResult = DialogResult.OK;
        }
        catch (OperationCanceledException)
        {
            if (!IsDisposed) SetState(L.T("login.cancelled"), L.T("login.retry"));
        }
        catch (Exception ex)
        {
            if (!IsDisposed) SetState(L.T("login.failed", ex.Message), L.T("login.retry"));
        }
        finally
        {
            _cts?.Dispose();
            _cts = null;
        }
    }

    protected override void OnFormClosed(FormClosedEventArgs e)
    {
        _cts?.Cancel();
        base.OnFormClosed(e);
    }

    protected override void DrawContent(Graphics g)
    {
        if (TaskbarStrip.Mark is not { } mark) return;
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.DrawImage(mark, Width / 2 - 28, 38, 56, 56);
    }
}
