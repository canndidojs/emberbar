using System.Globalization;

namespace EmberBar;

static class L
{
    public static readonly (string Code, string Name)[] Languages =
        { ("en", "English"), ("pt", "Português (Brasil)"), ("es", "Español") };

    static readonly CultureInfo[] Cultures =
        { CultureInfo.GetCultureInfo("en-US"), CultureInfo.GetCultureInfo("pt-BR"), CultureInfo.GetCultureInfo("es-ES") };

    static int _index;

    public static string Code => Languages[_index].Code;

    public static void Set(string? code)
    {
        int i = Array.FindIndex(Languages, l => l.Code == code);
        _index = i >= 0 ? i : 0;
    }

    public static string Detect() => CultureInfo.CurrentUICulture.TwoLetterISOLanguageName switch
    {
        "pt" => "pt",
        "es" => "es",
        _ => "en"
    };

    public static string T(string key, params object[] args) =>
        Table.TryGetValue(key, out var texts) ? string.Format(Cultures[_index], texts[_index], args) : key;

    public static string Clock(DateTime t) => t.ToString(_index == 0 ? "h:mm tt" : "HH:mm", Cultures[_index]);

    public static string Remaining(TimeSpan t, bool compact)
    {
        int days = (int)t.TotalDays, hours = t.Hours, mins = t.Minutes;
        if (t.TotalMinutes < 1) return compact ? "<1m" : "<1 min";
        if (days > 0) return compact ? $"{days}d{hours}h" : $"{days}d {hours}h";
        if (t.TotalHours >= 1) return compact ? $"{(int)t.TotalHours}h{mins:00}" : $"{(int)t.TotalHours}h {mins:00}min";
        return compact ? $"{mins}m" : $"{mins} min";
    }

    public static string Time(DateTimeOffset t, bool withDay) =>
        t.ToString((withDay ? "ddd " : "") + (_index == 0 ? "h:mm tt" : "HH:mm"), Cultures[_index]);

    static readonly Dictionary<string, string[]> Table = new()
    {
        ["menu.refresh"] = new[] { "Refresh now", "Atualizar agora", "Actualizar ahora" },
        ["menu.signin"] = new[] { "Sign in…", "Entrar…", "Iniciar sesión…" },
        ["menu.signout"] = new[] { "Sign out", "Sair da conta", "Cerrar sesión" },
        ["menu.interval"] = new[] { "Refresh every", "Atualizar a cada", "Actualizar cada" },
        ["interval.minutes"] = new[] { "{0} minutes", "{0} minutos", "{0} minutos" },
        ["menu.size"] = new[] { "Strip size", "Tamanho da faixa", "Tamaño de la barra" },
        ["size.small"] = new[] { "Small", "Pequeno", "Pequeño" },
        ["size.medium"] = new[] { "Medium", "Médio", "Mediano" },
        ["size.large"] = new[] { "Large", "Grande", "Grande" },
        ["menu.language"] = new[] { "Language", "Idioma", "Idioma" },
        ["menu.startup"] = new[] { "Start with Windows", "Iniciar com o Windows", "Iniciar con Windows" },
        ["on"] = new[] { "On", "Ligado", "Activado" },
        ["off"] = new[] { "Off", "Desligado", "Desactivado" },
        ["menu.usage"] = new[] { "Open usage page", "Abrir página de uso", "Abrir página de uso" },
        ["menu.about"] = new[] { "About EmberBar", "Sobre o EmberBar", "Acerca de EmberBar" },
        ["menu.quit"] = new[] { "Quit", "Sair", "Salir" },
        ["menu.status"] = new[] { "Version {0}  ·  {1}", "Versão {0}  ·  {1}", "Versión {0}  ·  {1}" },
        ["status.signedin"] = new[] { "Signed in", "Conectado", "Sesión iniciada" },
        ["status.signedout"] = new[] { "Not signed in", "Sem login", "Sin sesión" },

        ["strip.week"] = new[] { "W", "S", "S" },

        ["tip.loading"] = new[] { "EmberBar: loading…", "EmberBar: carregando…", "EmberBar: cargando…" },
        ["tip.notsignedin"] = new[] { "Not signed in. Right-click > Sign in.", "Sem login. Botão direito > Entrar.", "Sin sesión. Clic derecho > Iniciar sesión." },
        ["tip.signedout"] = new[] { "Signed out. Right-click > Sign in.", "Você saiu da conta. Botão direito > Entrar.", "Sesión cerrada. Clic derecho > Iniciar sesión." },
        ["tip.nodata"] = new[] { "No data: {0}", "Sem dados: {0}", "Sin datos: {0}" },
        ["tip.updated"] = new[] { "Updated at {0}", "Atualizado às {0}", "Actualizado a las {0}" },
        ["tip.stale"] = new[]
        {
            "Last known values, from {0}. Last error: {1}",
            "Últimos valores conhecidos, de {0}. Último erro: {1}",
            "Últimos valores conocidos, de {0}. Último error: {1}"
        },
        ["tip.weekly"] = new[] { "Weekly", "Semanal", "Semanal" },
        ["tip.resets"] = new[] { " (resets {0}, in {1})", " (reinicia {0}, em {1})", " (se restablece {0}, en {1})" },
        ["tip.resets0"] = new[] { " (resets {0})", " (reinicia {0})", " (se restablece {0})" },
        ["menu.showreset"] = new[] { "Show time until reset", "Mostrar tempo até resetar", "Mostrar tiempo hasta el reinicio" },
        ["menu.notify"] = new[] { "Usage alerts", "Alertas de uso", "Alertas de uso" },
        ["menu.update"] = new[] { "Update available: {0}", "Atualização disponível: {0}", "Actualización disponible: {0}" },
        ["alert.level"] = new[] { "{0} usage reached {1}%.{2}", "Uso {0} chegou a {1}%.{2}", "El uso {0} llegó al {1}%.{2}" },
        ["alert.full"] = new[] { "{0} limit reached.{1}", "Limite {0} atingido.{1}", "Límite {0} alcanzado.{1}" },
        ["alert.in"] = new[] { " Resets in {0}.", " Reinicia em {0}.", " Se restablece en {0}." },
        ["alert.five"] = new[] { "5-hour", "de 5h", "de 5h" },
        ["alert.week"] = new[] { "weekly", "semanal", "semanal" },
        ["update.toast"] = new[] { "EmberBar {0} is available. Click to download.", "EmberBar {0} disponível. Clique para baixar.", "EmberBar {0} disponible. Haz clic para descargar." },

        ["err.rate"] = new[]
        {
            "rate limited (HTTP 429), will retry",
            "limite de requisições (HTTP 429), vou tentar de novo",
            "límite de solicitudes (HTTP 429), se reintentará"
        },
        ["err.http"] = new[] { "HTTP {0}", "HTTP {0}", "HTTP {0}" },
        ["err.nofield"] = new[]
        {
            "response has no '{0}' (API changed?)",
            "a resposta não tem '{0}' (a API mudou?)",
            "la respuesta no tiene '{0}' (¿cambió la API?)"
        },
        ["err.badvalue"] = new[]
        {
            "'{0}.utilization' invalid (API changed?)",
            "'{0}.utilization' inválido (a API mudou?)",
            "'{0}.utilization' no válido (¿cambió la API?)"
        },
        ["err.notsignedin"] = new[] { "not signed in. Right-click > Sign in.", "sem login. Botão direito > Entrar.", "sin sesión. Clic derecho > Iniciar sesión." },
        ["err.expired"] = new[] { "session expired. Right-click > Sign in.", "a sessão expirou. Botão direito > Entrar.", "la sesión expiró. Clic derecho > Iniciar sesión." },
        ["err.server"] = new[]
        {
            "sign-in server answered HTTP {0}",
            "o servidor de login respondeu HTTP {0}",
            "el servidor de inicio de sesión respondió HTTP {0}"
        },
        ["err.norefresh"] = new[]
        {
            "the server sent no refresh token",
            "o servidor não enviou o token de renovação",
            "el servidor no envió el token de renovación"
        },
        ["err.badresponse"] = new[]
        {
            "invalid response from the sign-in page",
            "resposta inválida da página de login",
            "respuesta no válida de la página de inicio de sesión"
        },

        ["web.notfound"] = new[] { "Not found.", "Não encontrado.", "No encontrado." },
        ["web.failed"] = new[] { "Sign-in failed: {0}", "Falha no login: {0}", "Error al iniciar sesión: {0}" },
        ["web.invalid"] = new[] { "Invalid sign-in response.", "Resposta de login inválida.", "Respuesta de inicio de sesión no válida." },
        ["web.ok"] = new[]
        {
            "You're signed in. You can close this tab.",
            "Login concluído. Você já pode fechar esta aba.",
            "Sesión iniciada. Ya puedes cerrar esta pestaña."
        },

        ["login.intro"] = new[]
        {
            "Sign in with your Claude account to see your usage on the taskbar.",
            "Entre com sua conta do Claude para ver seu uso na barra de tarefas.",
            "Inicia sesión con tu cuenta de Claude para ver tu uso en la barra de tareas."
        },
        ["login.button"] = new[] { "Sign in with Claude", "Entrar com o Claude", "Iniciar sesión con Claude" },
        ["login.waiting"] = new[]
        {
            "Finish signing in on the page that just opened in your browser.",
            "Conclua o login na página que acabou de abrir no navegador.",
            "Termina de iniciar sesión en la página que se abrió en tu navegador."
        },
        ["login.cancel"] = new[] { "Cancel", "Cancelar", "Cancelar" },
        ["login.done"] = new[]
        {
            "You're signed in.\nEmberBar is now running on your taskbar.",
            "Login concluído.\nO EmberBar já está na sua barra de tarefas.",
            "Sesión iniciada.\nEmberBar ya está en tu barra de tareas."
        },
        ["login.cancelled"] = new[] { "Sign-in cancelled.", "Login cancelado.", "Inicio de sesión cancelado." },
        ["login.retry"] = new[] { "Try again", "Tentar de novo", "Intentar de nuevo" },
        ["login.failed"] = new[] { "Sign-in failed: {0}", "Falha no login: {0}", "Error al iniciar sesión: {0}" },

        ["about.version"] = new[] { "Version {0}", "Versão {0}", "Versión {0}" },
        ["about.desc"] = new[]
        {
            "Shows your Claude usage limits on the Windows taskbar.",
            "Mostra seus limites de uso do Claude na barra de tarefas do Windows.",
            "Muestra tus límites de uso de Claude en la barra de tareas de Windows."
        },
        ["about.author"] = new[]
        {
            "Made by Fabrício Candido.",
            "Feito por Fabrício Candido.",
            "Hecho por Fabrício Candido."
        },
        ["about.star"] = new[]
        {
            "Please give EmberBar a star on GitHub!",
            "Dê uma estrela ao EmberBar no GitHub!",
            "¡Dale una estrella a EmberBar en GitHub!"
        },
        ["about.starbutton"] = new[] { "Star on GitHub", "Dar estrela no GitHub", "Dar estrella en GitHub" },
        ["about.trademark"] = new[]
        {
            "Independent app. Not affiliated with, endorsed by, or sponsored by Anthropic.",
            "App independente. Sem afiliação, aprovação ou patrocínio da Anthropic.",
            "Aplicación independiente. Sin afiliación, respaldo ni patrocinio de Anthropic."
        },
        ["about.close"] = new[] { "Close", "Fechar", "Cerrar" }
    };
}
