using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Web;

namespace EmberBar;

record Tokens(string Access, string Refresh, DateTimeOffset Expires);

class NotSignedInException : Exception
{
    public NotSignedInException(string? message = null) : base(message ?? L.T("err.notsignedin")) { }
}

static class Auth
{
    const string ClientId = "9d1c250a-e61b-44d9-88ed-5944d1962f5e";
    const string AuthorizeUrl = "https://claude.com/cai/oauth/authorize";
    const string TokenUrl = "https://platform.claude.com/v1/oauth/token";
    const string Scope = "user:profile";

    static readonly string StoreFile = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "EmberBar", "auth.dat");
    static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public static bool SignedIn => Load() is not null;

    public static void SignOut()
    {
        if (File.Exists(StoreFile)) File.Delete(StoreFile);
    }

    public static async Task<string> GetAccessTokenAsync()
    {
        Tokens t = Load() ?? throw new NotSignedInException();
        if (t.Expires - TimeSpan.FromMinutes(2) > DateTimeOffset.UtcNow) return t.Access;

        try
        {
            t = await RequestAsync(new { grant_type = "refresh_token", refresh_token = t.Refresh, client_id = ClientId, scope = Scope }, t.Refresh);
        }
        catch (HttpRequestException ex) when (ex.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
        {
            SignOut();
            throw new NotSignedInException(L.T("err.expired"));
        }
        Save(t);
        return t.Access;
    }

    public static async Task LoginAsync(CancellationToken ct)
    {
        string verifier = Base64Url(RandomNumberGenerator.GetBytes(32));
        string challenge = Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier)));
        string state = Base64Url(RandomNumberGenerator.GetBytes(32));

        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            int port = ((IPEndPoint)listener.LocalEndpoint).Port;
            string redirect = $"http://localhost:{port}/callback";
            string url = AuthorizeUrl + "?code=true"
                + "&client_id=" + ClientId
                + "&response_type=code"
                + "&redirect_uri=" + Uri.EscapeDataString(redirect)
                + "&scope=" + Uri.EscapeDataString(Scope)
                + "&code_challenge=" + challenge
                + "&code_challenge_method=S256"
                + "&state=" + state;
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });

            string code = await WaitForCodeAsync(listener, state, ct);
            Save(await RequestAsync(new
            {
                grant_type = "authorization_code",
                code,
                redirect_uri = redirect,
                client_id = ClientId,
                code_verifier = verifier,
                state
            }, null));
        }
        finally { listener.Stop(); }
    }

    static async Task<string> WaitForCodeAsync(TcpListener listener, string state, CancellationToken ct)
    {
        while (true)
        {
            using TcpClient client = await listener.AcceptTcpClientAsync(ct);
            using NetworkStream stream = client.GetStream();
            var buffer = new byte[8192];
            int n = await stream.ReadAsync(buffer, ct);
            string[] request = Encoding.ASCII.GetString(buffer, 0, n).Split("\r\n")[0].Split(' ');

            if (request.Length < 2 || !request[1].StartsWith("/callback"))
            {
                await Reply(stream, L.T("web.notfound"), 404);
                continue;
            }

            var query = HttpUtility.ParseQueryString(new Uri("http://localhost" + request[1]).Query);
            if (query["error"] is { } error)
            {
                await Reply(stream, L.T("web.failed", error), 400);
                throw new Exception(error);
            }
            if (query["state"] != state || query["code"] is not { Length: > 0 } code)
            {
                await Reply(stream, L.T("web.invalid"), 400);
                throw new Exception(L.T("err.badresponse"));
            }

            await Reply(stream, L.T("web.ok"), 200);
            return code;
        }
    }

    static async Task Reply(NetworkStream stream, string message, int status)
    {
        string html = "<!doctype html><meta charset=utf-8><title>EmberBar</title>" +
            "<body style=\"margin:0;height:100vh;display:grid;place-items:center;background:#000;color:#fff;font:16px 'Segoe UI',sans-serif\">" +
            "<p>" + WebUtility.HtmlEncode(message) + "</p>";
        byte[] body = Encoding.UTF8.GetBytes(html);
        string head = $"HTTP/1.1 {status} OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {body.Length}\r\nConnection: close\r\n\r\n";
        await stream.WriteAsync(Encoding.ASCII.GetBytes(head));
        await stream.WriteAsync(body);
    }

    static async Task<Tokens> RequestAsync(object body, string? previousRefresh)
    {
        using var resp = await Http.PostAsJsonAsync(TokenUrl, body);
        if (!resp.IsSuccessStatusCode)
            throw new HttpRequestException(L.T("err.server", (int)resp.StatusCode), null, resp.StatusCode);

        using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync());
        var root = doc.RootElement;
        string access = root.GetProperty("access_token").GetString()!;
        string refresh = root.TryGetProperty("refresh_token", out var r) && r.GetString() is { Length: > 0 } fresh
            ? fresh
            : previousRefresh ?? throw new Exception(L.T("err.norefresh"));
        return new Tokens(access, refresh, DateTimeOffset.UtcNow.AddSeconds(root.GetProperty("expires_in").GetDouble()));
    }

    static void Save(Tokens t)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(StoreFile)!);
        byte[] plain = JsonSerializer.SerializeToUtf8Bytes(new { access = t.Access, refresh = t.Refresh, expires = t.Expires.ToUnixTimeMilliseconds() });
        string temp = StoreFile + ".tmp";
        File.WriteAllBytes(temp, ProtectedData.Protect(plain, null, DataProtectionScope.CurrentUser));
        File.Move(temp, StoreFile, true);
    }

    static Tokens? Load()
    {
        try
        {
            if (!File.Exists(StoreFile)) return null;
            byte[] plain = ProtectedData.Unprotect(File.ReadAllBytes(StoreFile), null, DataProtectionScope.CurrentUser);
            using var doc = JsonDocument.Parse(plain);
            var root = doc.RootElement;
            return new Tokens(
                root.GetProperty("access").GetString()!,
                root.GetProperty("refresh").GetString()!,
                DateTimeOffset.FromUnixTimeMilliseconds(root.GetProperty("expires").GetInt64()));
        }
        catch { return null; }
    }

    static string Base64Url(byte[] bytes) =>
        Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
