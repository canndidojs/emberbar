import Foundation

public enum Lang: String, CaseIterable {
    case en, pt, es

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .pt: return "Português (Brasil)"
        case .es: return "Español"
        }
    }

    /// Best match for the system language list, English if none.
    public static func detect(preferred: [String] = Locale.preferredLanguages) -> Lang {
        for tag in preferred {
            let code = tag.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
            if let lang = Lang(rawValue: code) { return lang }
        }
        return .en
    }
}

/// UI strings in English, Portuguese (Brazil) and Spanish. `%@`/`%d` placeholders are positional by order.
public enum L {
    public static var current: Lang = .detect()

    public static func t(_ key: String, _ args: CVarArg...) -> String {
        let template = table[current]?[key] ?? table[.en]?[key] ?? key
        return args.isEmpty ? template : String(format: template, arguments: args)
    }

    public static func t(_ key: String, in lang: Lang, _ args: CVarArg...) -> String {
        let template = table[lang]?[key] ?? key
        return args.isEmpty ? template : String(format: template, arguments: args)
    }

    static let table: [Lang: [String: String]] = [
        .en: [
            "short.five": "5h", "short.week": "W",
            "menu.signin": "Sign in with Claude", "menu.signout": "Sign out",
            "menu.refresh": "Refresh now", "menu.interval": "Update every",
            "menu.language": "Language", "menu.startup": "Open at login",
            "menu.usage": "Open usage page", "menu.quit": "Quit EmberBar",
            "menu.update": "Update available: %@", "menu.checkupdate": "Check for updates",
            "line.five": "5-hour limit: %d%%", "line.week": "Weekly limit: %d%%",
            "line.resets": "Resets %@ (in %@)", "line.resets.now": "Resets %@",
            "line.updated": "Updated %@", "line.stale": "Showing the last known values",
            "state.loading": "Loading…", "state.waiting": "Waiting for the browser…",
            "state.uptodate": "You have the latest version",
            "menu.history": "Usage history…", "menu.notify": "Usage alerts",
            "alert.five": "5-hour limit", "alert.week": "Weekly limit",
            "alert.level": "%@ reached %d%%.", "alert.full": "%@ is full.", "alert.in": "Resets in %@.",
            "hist.title": "Usage history", "hist.sub": "Last 6 months",
            "hist.five": "5-hour limit (average of daily peaks)", "hist.week": "Weekly limit (highest peak)",
            "hist.note": "Recorded only on this Mac while EmberBar is running. Claude offers no past data, so the history starts when you first run EmberBar.",
            "hist.clear": "Clear history", "hist.clearask": "Delete all recorded history?",
            "hist.empty": "No data yet", "hist.day": "1 day", "hist.days": "%d days",
            "common.cancel": "Cancel",
            "unit.min": "min", "unit.h": "h", "unit.d": "d",
            "err.notsignedin": "Not signed in.", "err.expired": "Session expired. Sign in again.",
            "err.badresponse": "Invalid response from the sign-in page.",
            "err.server": "Server error (%d).", "err.norefresh": "The server did not return a refresh token.",
            "err.timeout": "Sign-in timed out. Try again.",
            "err.storage": "Could not save the session in the Keychain.",
            "err.rate": "Rate limited by the server.", "err.http": "HTTP error %d.",
            "web.ok": "Signed in. You can close this tab.", "web.failed": "Sign-in failed. You can close this tab.",
            "web.invalid": "Invalid request.", "web.notfound": "Not found.",
        ],
        .pt: [
            "short.five": "5h", "short.week": "S",
            "menu.signin": "Entrar com o Claude", "menu.signout": "Sair",
            "menu.refresh": "Atualizar agora", "menu.interval": "Atualizar a cada",
            "menu.language": "Idioma", "menu.startup": "Abrir ao iniciar o Mac",
            "menu.usage": "Abrir página de uso", "menu.quit": "Sair do EmberBar",
            "menu.update": "Atualização disponível: %@", "menu.checkupdate": "Procurar atualizações",
            "line.five": "Limite de 5 horas: %d%%", "line.week": "Limite semanal: %d%%",
            "line.resets": "Reinicia %@ (em %@)", "line.resets.now": "Reinicia %@",
            "line.updated": "Atualizado %@", "line.stale": "Mostrando os últimos valores conhecidos",
            "state.loading": "Carregando…", "state.waiting": "Aguardando o navegador…",
            "state.uptodate": "Você está na versão mais recente",
            "menu.history": "Histórico de uso…", "menu.notify": "Alertas de uso",
            "alert.five": "Limite de 5 horas", "alert.week": "Limite semanal",
            "alert.level": "%@ chegou a %d%%.", "alert.full": "%@ esgotado.", "alert.in": "Reinicia em %@.",
            "hist.title": "Histórico de uso", "hist.sub": "Últimos 6 meses",
            "hist.five": "Limite de 5 horas (média dos picos diários)", "hist.week": "Limite semanal (maior pico)",
            "hist.note": "Registrado apenas neste Mac enquanto o EmberBar está aberto. O Claude não oferece dados passados, então o histórico começa na primeira vez que você abre o EmberBar.",
            "hist.clear": "Limpar histórico", "hist.clearask": "Apagar todo o histórico registrado?",
            "hist.empty": "Ainda sem dados", "hist.day": "1 dia", "hist.days": "%d dias",
            "common.cancel": "Cancelar",
            "unit.min": "min", "unit.h": "h", "unit.d": "d",
            "err.notsignedin": "Você não está conectado.", "err.expired": "A sessão expirou. Entre novamente.",
            "err.badresponse": "Resposta inválida da página de login.",
            "err.server": "Erro do servidor (%d).", "err.norefresh": "O servidor não devolveu um token de renovação.",
            "err.timeout": "O login demorou demais. Tente de novo.",
            "err.storage": "Não foi possível salvar a sessão no Chaveiro.",
            "err.rate": "Limite de requisições do servidor.", "err.http": "Erro HTTP %d.",
            "web.ok": "Conectado. Você pode fechar esta aba.", "web.failed": "Falha no login. Você pode fechar esta aba.",
            "web.invalid": "Requisição inválida.", "web.notfound": "Não encontrado.",
        ],
        .es: [
            "short.five": "5h", "short.week": "S",
            "menu.signin": "Iniciar sesión con Claude", "menu.signout": "Cerrar sesión",
            "menu.refresh": "Actualizar ahora", "menu.interval": "Actualizar cada",
            "menu.language": "Idioma", "menu.startup": "Abrir al iniciar sesión",
            "menu.usage": "Abrir página de uso", "menu.quit": "Salir de EmberBar",
            "menu.update": "Actualización disponible: %@", "menu.checkupdate": "Buscar actualizaciones",
            "line.five": "Límite de 5 horas: %d%%", "line.week": "Límite semanal: %d%%",
            "line.resets": "Se reinicia %@ (en %@)", "line.resets.now": "Se reinicia %@",
            "line.updated": "Actualizado %@", "line.stale": "Mostrando los últimos valores conocidos",
            "state.loading": "Cargando…", "state.waiting": "Esperando al navegador…",
            "state.uptodate": "Tienes la última versión",
            "menu.history": "Historial de uso…", "menu.notify": "Alertas de uso",
            "alert.five": "Límite de 5 horas", "alert.week": "Límite semanal",
            "alert.level": "%@ llegó al %d%%.", "alert.full": "%@ agotado.", "alert.in": "Se reinicia en %@.",
            "hist.title": "Historial de uso", "hist.sub": "Últimos 6 meses",
            "hist.five": "Límite de 5 horas (promedio de los picos diarios)", "hist.week": "Límite semanal (mayor pico)",
            "hist.note": "Se guarda solo en este Mac mientras EmberBar está abierto. Claude no ofrece datos pasados, así que el historial empieza la primera vez que abres EmberBar.",
            "hist.clear": "Borrar historial", "hist.clearask": "¿Eliminar todo el historial registrado?",
            "hist.empty": "Aún sin datos", "hist.day": "1 día", "hist.days": "%d días",
            "common.cancel": "Cancelar",
            "unit.min": "min", "unit.h": "h", "unit.d": "d",
            "err.notsignedin": "No has iniciado sesión.", "err.expired": "La sesión expiró. Inicia sesión de nuevo.",
            "err.badresponse": "Respuesta no válida de la página de inicio de sesión.",
            "err.server": "Error del servidor (%d).", "err.norefresh": "El servidor no devolvió un token de renovación.",
            "err.timeout": "El inicio de sesión tardó demasiado. Inténtalo de nuevo.",
            "err.storage": "No se pudo guardar la sesión en el Llavero.",
            "err.rate": "Límite de solicitudes del servidor.", "err.http": "Error HTTP %d.",
            "web.ok": "Sesión iniciada. Puedes cerrar esta pestaña.", "web.failed": "Error al iniciar sesión. Puedes cerrar esta pestaña.",
            "web.invalid": "Solicitud no válida.", "web.notfound": "No encontrado.",
        ],
    ]
}
