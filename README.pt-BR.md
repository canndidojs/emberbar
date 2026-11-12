<p align="center">
  <img src="app-mark.png" width="128" alt="Logo do EmberBar">
</p>

<h1 align="center">EmberBar</h1>

<p align="center">
  <b>Seus limites de uso do Claude sempre à vista na barra de tarefas do Windows.</b><br>
  Pequeno, privado, de código aberto e fácil de ler em poucos minutos.
</p>

<p align="center">
  <img alt="Windows 10" src="https://img.shields.io/badge/Windows-10-0078D4?logo=windows&logoColor=white">
  <img alt=".NET 8" src="https://img.shields.io/badge/.NET-8-512BD4?logo=dotnet&logoColor=white">
  <img alt="Sem telemetria" src="https://img.shields.io/badge/telemetria-nenhuma-2ea44f">
  <img alt="Idiomas" src="https://img.shields.io/badge/idiomas-EN%20%7C%20PT--BR%20%7C%20ES-D97757">
</p>

<p align="center">
  <img src="docs/preview.png" width="460" alt="EmberBar em uma barra de tarefas clara e em uma escura">
</p>

<p align="center"><sub>Ilustração. <b>5h</b> é o seu limite de 5 horas e <b>S</b> (<b>W</b> em inglês) é o limite semanal.</sub></p>

<p align="center"><a href="README.md">Read in English</a></p>

---

## Por que o EmberBar?

O Claude tem limites de uso que reiniciam a cada 5 horas e a cada semana. Para conferir, você precisa abrir uma página ou um comando. O EmberBar coloca os dois números na barra de tarefas, ao lado do relógio, para você saber sempre quanto ainda tem antes de bater no limite.

- **Dois números, um olhar.** O limite de 5 horas e o semanal, atualizados em segundo plano.
- **Cores que avisam.** Texto normal abaixo de 70%, laranja a partir de 70% e vermelho a partir de 90%.
- **Sempre mostra algo.** Se uma atualização falhar, ele mantém os últimos valores em cinza em vez de ficar em branco.
- **Privado por projeto.** Sem telemetria, sem análise de uso, e só fala com dois endereços da Anthropic.
- **Fácil de auditar.** Cerca de 1.100 linhas de C# em 9 arquivos, sem pacotes NuGet, e todo o login cabe em um arquivo.
- **No seu idioma.** English, Português (Brasil) e Español, escolhidos no menu.

## Começando

Você precisa do [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) para compilar (`winget install Microsoft.DotNet.SDK.8`) e do .NET 8 Desktop Runtime para rodar.

```powershell
git clone https://github.com/canndidojs/emberbar.git
cd emberbar
dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true -o publish
.\publish\EmberBar.exe
```

Na primeira vez, uma janelinha preta e branca pede o login. Clique no botão, entre na página que abre no navegador, e a janela avisa que o EmberBar está rodando e fecha sozinha. A faixa fica na barra de tarefas.

> Não existe um download pronto, de propósito: você compila a partir do código que pode ler.

## Como usar

Clique com o botão direito na faixa para abrir o menu.

| Item do menu | O que faz |
|---|---|
| **Atualizar agora** | Atualiza os números na hora. |
| **Entrar / Sair da conta** | Inicia o login ou apaga a sessão salva. |
| **Atualizar a cada** | 2, 5, 10, 15 ou 30 minutos. O padrão é 5. |
| **Tamanho da faixa** | Pequeno, médio ou grande. |
| **Idioma** | English, Português (Brasil) ou Español. Na primeira vez segue o idioma do Windows. |
| **Iniciar com o Windows** | Desligado por padrão. Mostra *Ligado* ou *Desligado*. |
| **Abrir página de uso** | Abre a sua página de uso no navegador. |
| **Sobre o EmberBar** | Versão, autor e um link para dar estrela no projeto. |
| **Sair** | Fecha o app. |

Passe o mouse sobre a faixa para ver as porcentagens exatas, quando cada limite reinicia e quando os números foram atualizados pela última vez.

### Bom saber

- A faixa se esconde enquanto um app ou jogo em tela cheia está aberto, e quando a barra de tarefas está na lateral da tela.
- Depois de um erro, a espera até a próxima tentativa dobra (até 10 minutos) para ficar abaixo do limite de requisições da API.
- É uma janelinha desenhada sobre a barra de tarefas, e não uma parte nativa dela, porque o Windows 10 não tem um jeito oficial de fazer isso. Se a barra estiver lotada, ela pode cobrir os últimos botões.
- Feito e testado no Windows 10. Pode funcionar no Windows 11, mas isso não foi testado.

## Privacidade e segurança

| | |
|---|---|
| **Rede** | Só `api.anthropic.com` (o seu uso) e `platform.claude.com` (login e renovação da sessão). Quem abre a página de login é o seu navegador, e não o app. |
| **Telemetria** | Nenhuma. Sem análise de uso, sem relatório de falhas, sem busca de atualizações. |
| **Guarda** | `%APPDATA%\EmberBar\auth.dat`, a sua sessão, criptografada com o DPAPI do Windows para só o seu usuário conseguir ler. E `%APPDATA%\EmberBar\settings.json`, com intervalo, tamanho e idioma. |
| **Registro** | Só se você ligar *Iniciar com o Windows*: um valor em `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`. |
| **Escuta** | Uma única requisição em `localhost`, em uma porta aleatória, só enquanto a janela de login espera por você. |
| **Tela** | Lê a cor de **um pixel** da barra de tarefas para o fundo da faixa combinar com ela. Nada é salvo nem enviado. |
| **Outros apps** | Não lê nem altera arquivos ou logins de nenhum outro programa. |

Para conferir a rede você mesmo: os únicos endereços que o app contata são `Url` em `Program.cs` e `TokenUrl` em `Auth.cs`.

## Como o login funciona

1. O EmberBar abre a página de login no seu navegador padrão, com um desafio PKCE aleatório e um `state`.
2. Você entra por lá. A página manda o seu navegador para `http://localhost:<porta aleatória>/callback`, onde o EmberBar espera por essa única requisição.
3. O EmberBar troca o código por uma sessão e a salva, criptografada, em `%APPDATA%\EmberBar\auth.dat`.
4. Antes do token de acesso expirar, o EmberBar o renova em segundo plano. Se a renovação for recusada, ele tira você da conta e pede um novo login.

A sua senha nunca passa pelo EmberBar.

## Perguntas frequentes

**O antivírus vai acusar?**
Não deveria, mas pode acontecer com qualquer programa pequeno e sem assinatura. O Windows Defender escaneou a compilação e não achou nada. Como você mesmo compila, o Windows não mostra o aviso de "baixado da internet". Se algum antivírus acusar, você pode enviar o arquivo ao fabricante como falso positivo.

**Por que às vezes os números ficam cinza?**
A última atualização falhou (por exemplo limite de requisições ou falta de internet), então o EmberBar mostra os últimos valores conhecidos. Passe o mouse sobre a faixa para ver de quando eles são e o que falhou.

**Por que a cada 5 minutos?**
O endereço de uso tem limite de requisições. Um intervalo curto pode causar erro. Você pode escolher outro intervalo no menu.

**Isso gasta a cota do meu plano?**
Ele só lê os seus limites. Nunca envia mensagens ao modelo.

**Como removo por completo?**
1. Clique com o botão direito na faixa, desligue *Iniciar com o Windows* e depois *Sair*.
2. Apague a pasta do projeto e `%APPDATA%\EmberBar`.
3. Se quiser, revogue o acesso do app nas configurações da sua conta do Claude.

## Estrutura do projeto

| Arquivo | O que faz |
|---|---|
| `Program.cs` | Início, menu, temporizador e a única requisição de uso. |
| `Auth.cs` | Login (OAuth com PKCE), renovação da sessão e armazenamento criptografado. |
| `Settings.cs` | Salva intervalo, tamanho e idioma. |
| `L.cs` | Todos os textos, em três idiomas. |
| `TaskbarStrip.cs` | A faixa desenhada na barra de tarefas. |
| `DarkMenu.cs` | O visual escuro do menu de contexto. |
| `MinimalWindow.cs` | Estilo preto e branco compartilhado das janelas. |
| `LoginWindow.cs` | A janela de login. |
| `AboutWindow.cs` | A janela Sobre. |

## Riscos e limites

1. **Endereço não oficial.** O endereço de uso não é documentado publicamente e pode mudar ou sumir sem aviso. Se isso acontecer, a faixa para de atualizar e o tooltip explica o motivo.
2. **Identidade de login emprestada.** A Anthropic não oferece um login público para apps de terceiros, então o EmberBar entra com o mesmo identificador OAuth público usado pela ferramenta de linha de comando da própria Anthropic (Claude Code). A sua conta vai listar a sessão com esse nome. A Anthropic pode mudar ou bloquear isso a qualquer momento, e pode não ser coberto pelos termos dela. Use por sua conta e risco.
3. **Sessão guardada.** Ela é criptografada com o DPAPI, mas qualquer programa rodando como o seu usuário do Windows pode pedir ao Windows para descriptografá-la. Leia o código antes de rodar.

## Autor

Feito por **[Fabrício Candido](https://github.com/canndidojs)**.

Se o EmberBar for útil para você, uma ⭐ no GitHub ajuda muito.

## Aviso

O EmberBar é um projeto independente. Não tem afiliação, aprovação nem patrocínio da Anthropic. *Claude* é uma marca da Anthropic, PBC, citada aqui só para dizer com o que o app funciona. É fornecido como está, sem garantia de nenhum tipo, e você é responsável por revisar o código e pelo uso que faz dele.
