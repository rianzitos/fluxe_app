<p align="center">
  <img src="https://fluxeteam.com.br/public/img/logotipo.svg" width="300" align="middle" alt="Logo Fluxe" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://fluxeteam.com.br/public/img/logo_sicapda.png" width="300" align="middle" alt="Logo SICAPDA" />
</p>

# SICAPDA App · fluxe_app

Aplicativo do **SICAPDA** para **Android, Windows e navegador** — *Sistema Inteligente de Controle de Acesso e Previsão de Demanda Alimentar*, desenvolvido pela **Fluxe**.

Feito em **Flutter (Dart)**, ele traz para o celular, o computador e o navegador as mesmas telas e funcionalidades da versão web ([SystemFluxe](https://github.com/rianzitos/SystemFluxe)), lendo o **mesmo banco de dados MySQL**: o que muda na web aparece no app, e vice-versa.

📲 **Quer usar?** Na página [fluxeteam.com.br/sicapda#baixar](https://fluxeteam.com.br/sicapda#baixar) você baixa o aplicativo para **Android** (`.apk`) ou **Windows**, ou toca em **Abrir no navegador** (a [versão web](#versão-web), que funciona em qualquer aparelho, inclusive iPhone, e instala na tela inicial). Para gerar e publicar, veja [Gerar e publicar o aplicativo](#gerar-e-publicar-o-aplicativo).

---

## Propósito do aplicativo

O SICAPDA une duas frentes em um só lugar: o **controle de acesso** de pessoas (colaboradores, visitantes, prestadores) e a **previsão da demanda de refeições** do refeitório. O painel web é onde o gestor cadastra e configura tudo; o **app existe para levar a gestão para a palma da mão**.

Ele foi pensado para quem não está o tempo todo na frente de um computador, como gestores, supervisores e responsáveis pela cozinha, e precisa de respostas rápidas durante o dia:

- **Quantas pessoas estão no local agora?** Quem entrou, a que horas e em qual grupo.
- **Quantas refeições e quantos quilos produzir amanhã?** A previsão é calculada com o histórico de acessos e produção, considerando feriados e dias da semana.
- **Estamos desperdiçando comida?** Acompanhamento diário e mensal de produção e desperdício, com alertas quando passa da meta.
- **O que aconteceu nos acessos?** Consulta e exportação dos registros de entrada e saída, com filtros.
- **Dúvidas rápidas.** O assistente responde perguntas como "previsão para sexta" ou "como está o desperdício?" em linguagem natural.

Na prática, o app ajuda a **planejar a produção com mais precisão, reduzir o desperdício de alimentos, ter mais segurança e visibilidade sobre quem circula na instituição** e tomar decisões com dados em tempo real, de qualquer lugar.

> O app é de **consulta e acompanhamento**: cadastros, configurações da empresa e a leitura das catracas continuam sendo feitos pela versão web e pelos dispositivos IoT. O app usa os mesmos dados.

---

## Como funciona

```
┌──────────────┐   HTTPS / JSON   ┌────────────────────────┐   PDO   ┌─────────────────┐
│  App Flutter │ ───────────────▶ │  SystemFluxe (PHP)     │ ──────▶ │ MySQL           │
│  (fluxe_app) │ ◀─────────────── │  rotas /api/*          │ ◀────── │ controle_acesso │
└──────────────┘  Bearer token    └────────────────────────┘         └─────────────────┘
```

O app **não** se conecta direto ao MySQL. Conectar um app de celular direto ao banco exigiria expor o banco na internet e guardar a senha dele dentro do APK, o que é inseguro. Em vez disso, o SystemFluxe expõe uma API JSON (`/api/*`) que reutiliza os mesmos *models* da web (`Painel`, `Acesso`, `Previsao`, `Assistente`...) e sempre filtra os dados pela **empresa do usuário logado**.

O login usa os **mesmos usuários e senhas da web**.

---

## Telas

| Tela | Equivalente na web | O que mostra |
|---|---|---|
| **Login** | `/login` | E-mail e senha; campo opcional para trocar o endereço do servidor |
| **Painel** | `/painel` | Usuários ativos, acessos, refeições previstas, acurácia, gráfico de previsão de demanda, distribuição de refeições, previsão das próximas horas, alertas e recomendações |
| **Análise mensal** | `/acessos` | Total produzido/desperdiçado, média de pessoas, gráficos diários e insights do mês, com seletor de mês |
| **Pessoas** | `/pessoas` | Quem está no local agora, por grupo (operadores, supervisores, prestadores), com busca |
| **Assistente IA** | `/assistente` | Chat com previsões (amanhã, sexta, semanal), desperdício, precisão, feriados; perguntas rápidas |
| **Relatórios** | `/relatorios` | Registros de acesso com filtro por período, nome/função e categoria; paginação; exportação em CSV |
| **Configurações** | `/configuracoes` | Perfil, tema (claro / escuro / sistema), endereço do servidor e sair da conta |

Outros detalhes: menu lateral escuro igual ao da web (no computador ele fica sempre visível e os cartões de resumo ficam lado a lado; no celular é um menu deslizante com barra de abas inferior), a logo oficial do SICAPDA, sino com a contagem de alertas, *pull-to-refresh* em todas as telas, tema claro e escuro, e identidade visual idêntica à web (cores `#0D0D0D` / `#FFC107`, fontes **Sora** e **Inter**).

---

## Como rodar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.12.2`)
- Para Android: Android Studio (emulador/SDK Android) ou um celular com depuração USB
- Para Windows: Visual Studio 2022 com a carga de trabalho **Desenvolvimento para desktop com C++** (confira com `flutter doctor`)
- O **SystemFluxe** rodando e acessível (veja a seção abaixo)

### 1. Configurar o servidor (SystemFluxe)

1. Em `SystemFluxe/config/.env`, adicione um segredo para assinar os tokens da API (mínimo de 32 caracteres):
   ```
   API_SECRET=cole-aqui-um-segredo-aleatorio-grande
   ```
   Para gerar um: `php -r "echo bin2hex(random_bytes(32));"`
   > Sem o `API_SECRET` a API responde erro 500.
2. Suba o servidor. Localmente, dentro da pasta do SystemFluxe:
   ```
   php -S 0.0.0.0:8000 -t public app/routes/web.php
   ```
   ou publique normalmente (Apache com o `public/` como *DocumentRoot*).

### 2. Rodar o app

```bash
flutter pub get
flutter run                # no celular/emulador conectado
flutter run -d windows     # no seu computador com Windows
flutter run -d chrome      # no navegador (a API do SystemFluxe responde CORS, então funciona apontando para qualquer servidor)
```

### 3. Apontar o app para o servidor

Na tela de login, toque em **Servidor** e informe o endereço do SystemFluxe. Depois do login, também dá para trocar em **Configurações → Servidor**.

| Onde o SystemFluxe está | Endereço |
|---|---|
| Produção | `https://fluxeteam.com.br` (padrão do app; na versão web publicada, o padrão é o próprio site de onde a página foi aberta) |
| Emulador Android → seu PC | `http://10.0.2.2:8000` |
| Celular físico na mesma rede Wi-Fi | `http://IP-DO-SEU-PC:8000` (ex.: `http://192.168.0.10:8000`) |
| App do Windows no mesmo PC do servidor | `http://localhost:8000` |

> **HTTP só para testes:** o APK aceita `http://` para você testar contra um servidor na sua rede (a tela de login avisa que o endereço não é criptografado), mas o servidor de produção `fluxeteam.com.br` é **sempre HTTPS** (regra em `android/app/src/main/res/xml/network_security_config.xml`). Em produção use sempre `https://`.

---

## Gerar e publicar o aplicativo

Os três jeitos de usar o app são oferecidos na página de apresentação do sistema, na seção **Baixar** (`/sicapda#baixar`, atalho `/app`): **Android** (`SICAPDA.apk`), **Windows** (`SICAPDA-Setup.exe`) e **Abrir no navegador** (a versão web). O botão principal entrega o instalador certo para o aparelho de quem acessa. Para gerar tudo **não precisa de Android Studio nem de Visual Studio**: o GitHub compila para você.

### Opção 1 — pelo GitHub (recomendado)

O workflow [`Build do aplicativo`](.github/workflows/build-app.yml) analisa, testa e compila o app (Android, web e Windows, em paralelo), **abre um emulador Android para testar o APK de verdade** (instala, abre, entra no app contra um servidor de mentira e reabre para conferir que a sessão foi salva) e publica os arquivos:

| Quando roda | O que acontece |
|---|---|
| Pull Request | Analisa, testa e compila. Os arquivos ficam em **Actions → execução → Artifacts**. |
| Push na `main` (ou tag `v*`) | Publica a **Release** `v<versão do pubspec.yaml>` com todos os arquivos anexados. Essa é a versão oficial. Se a Release da versão já existe, **não** é sobrescrita: aumente o `version:` para publicar de novo. |
| Push num branch `claude/**` ou **Run workflow** manual | Atualiza a Release **"Prévia de teste"** (`ci-preview`, marcada como pré-lançamento), para baixar e testar antes de mesclar. |

Arquivos de cada Release: `SICAPDA.apk` + `app.json` (Android), `SICAPDA-Setup.exe` + `app-windows.json` (Windows) e `SICAPDA-web.zip` (versão web). Os `.json` guardam versão, tamanho, SHA-256 e data.

**Para publicar uma versão:**

1. Aumente o `version:` do `pubspec.yaml` (ex.: `1.1.1+3`) e faça o merge na `main`. Em poucos minutos a Release `v1.1.1` aparece em **github.com/rianzitos/fluxe_app/releases**.
2. Baixe os arquivos da Release e copie para o **SystemFluxe**: `SICAPDA.apk` + `app.json` e `SICAPDA-Setup.exe` + `app-windows.json` em `storage/downloads/`; e o conteúdo de `SICAPDA-web.zip` em `public/aplicativo/` (mantendo o `.htaccess` que está lá). Pronto: a página passa a mostrar versão, tamanho e data, e os botões funcionam.

Também dá para criar a Release manualmente com uma tag: `git tag v1.1.1 && git push origin v1.1.1`.

### Opção 2 — no seu computador (Windows)

```powershell
.\tool\publicar_app.ps1                                    # Android, Windows e web → ..\SystemFluxe
.\tool\publicar_app.ps1 -Plataforma Web                    # só a versão web (ou -Plataforma Android / Windows)
.\tool\publicar_app.ps1 -Destino C:\Projetos\SystemFluxe   # SystemFluxe em outro lugar
.\tool\publicar_app.ps1 -Servidor https://fluxeteam.com.br # servidor padrão embutido no app
.\tool\publicar_app.ps1 -SemBuild                          # só publica o que já foi compilado
```

O script copia os instaladores para `storage\downloads` e a versão web para `public\aplicativo` do SystemFluxe. Para o instalador do Windows é preciso ter o [Inno Setup 6](https://jrsoftware.org/isdl.php) (`winget install JRSoftware.InnoSetup`). Passo a passo manual: `flutter build windows --release` e depois `.\tool\empacotar_windows.ps1`, que gera `dist\SICAPDA-Setup.exe`. No Android: `flutter build apk --release --target-platform android-arm,android-arm64,android-x64` (arquivo em `build/app/outputs/flutter-apk/app-release.apk`).

> O APK é **único para todos os aparelhos**: inclui ARM de 32 e 64 bits (todos os celulares e tablets) e **x86_64** (emulador do Android Studio, Chromebooks, BlueStacks). Por isso tem cerca de 27 MB (as bibliotecas nativas vão compactadas dentro do APK). Antes o APK só tinha ARM e dava erro de arquitetura ao instalar no emulador.

### Versão web

O mesmo app, compilado para o navegador. O SystemFluxe a serve como arquivos estáticos em **`/aplicativo/`** (pasta `public/aplicativo/`), na mesma origem da API, então não precisa configurar CORS nem endereço de servidor: **o app usa o próprio site de onde foi aberto**.

```bash
flutter build web --release --base-href /aplicativo/ --no-web-resources-cdn --pwa-strategy=none
```

- `--base-href /aplicativo/`: a pasta onde o SystemFluxe publica o app.
- `--no-web-resources-cdn`: leva o motor gráfico (CanvasKit) junto. Sem isso o navegador o baixa do `gstatic.com` do Google e, em redes que bloqueiam esse endereço (escolas, empresas), o app fica em branco para sempre.
- `--pwa-strategy=none`: sem o service worker obsoleto do Flutter. O `web/sw.js` do projeto é mínimo (não guarda nada em cache) e existe só para o navegador oferecer **Instalar aplicativo**.

Depois do build, o `publicar_app.ps1` e o CI tiram os renderizadores que o navegador não usa (`canvaskit/skwasm*`, `wimp*`, `webparagraph` e os `.symbols`), de ~43 MB para ~19 MB, e o `SICAPDA-web.zip` já sai assim.

- **Instalar na tela inicial:** Android (Chrome) → menu ⋮ → *Instalar aplicativo*; iPhone/iPad (Safari) → Compartilhar → *Adicionar à Tela de Início*; computador (Chrome/Edge) → ícone de instalar na barra de endereço.
- **Sessão:** no navegador o token fica no armazenamento do próprio navegador (o "cofre" da web exige HTTPS e falha em `http://`, por exemplo numa demonstração na rede local).
- **Ícones e logo:** o `web/` tem favicon, ícones do PWA (inclusive o "maskable" do Android e o `apple-touch-icon` do iPhone) e a tela de carregamento com a logo do SICAPDA. Para regenerar a partir da arte de `assets/icon/` e `assets/logo/`: `pip install pillow` e `python tool/gerar_icones_web.py`.
- **Servidor:** o `.htaccess` de `public/aplicativo/` (no SystemFluxe) comprime o motor gráfico (7 MB → 2 MB), define `application/wasm` e usa `Cache-Control: no-cache`, para uma versão nova aparecer sozinha.

### Instalador do Windows

- Instala só para o usuário atual (**não pede senha de administrador**), em português, com atalhos no Menu Iniciar e na Área de Trabalho. Um instalador mais novo atualiza o programa por cima do antigo.
- Funciona no Windows 10 ou superior (64 bits) e leva junto as DLLs do Visual C++, então não depende de nada instalado no computador do cliente.
- **Aviso do SmartScreen:** o instalador ainda não tem assinatura digital (isso exige um certificado de assinatura de código, que é pago). Na primeira execução o Windows pode mostrar "O Windows protegeu o seu computador": clique em **Mais informações → Executar assim mesmo**.
- No Windows, a exportação do relatório em CSV salva o arquivo na pasta **Downloads** (com botão para abrir a pasta).

### Assinatura do APK (importante para atualizações)

O Android só atualiza um app instalado quando o novo APK é assinado com a **mesma chave**. Sem chave própria o build usa a chave de *debug*: serve para testar, mas **muda a cada execução do GitHub Actions**, e aí quem já instalou precisa desinstalar a versão anterior antes de instalar a nova.

Para ter uma chave própria, crie uma vez e guarde o arquivo e as senhas em local seguro (se perder a chave, não há como atualizar o app dos usuários). **Nunca envie ao Git**; `key.properties` e `*.jks` já estão no `.gitignore`.

```bash
keytool -genkeypair -v -keystore sicapda-release.jks -alias sicapda -keyalg RSA -keysize 2048 -validity 10000
```

- **No GitHub:** em *Settings → Secrets and variables → Actions*, crie os secrets `ANDROID_KEYSTORE_BASE64` (saída de `base64 -w0 sicapda-release.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`sicapda`) e, se a senha da chave for diferente da do keystore, `ANDROID_KEY_PASSWORD`. A partir daí o workflow assina sozinho.
- **No seu computador:** coloque o `.jks` em `android/app/` e crie `android/key.properties`:
  ```properties
  storeFile=sicapda-release.jks
  storePassword=sua-senha
  keyAlias=sicapda
  keyPassword=sua-senha
  ```

### Outros detalhes

- **Servidor padrão:** `https://fluxeteam.com.br`. Para outro endereço na compilação: `flutter build apk --release --dart-define=SICAPDA_SERVER_URL=https://seu-servidor`. O usuário também pode trocar em **Servidor** na tela de login.
- **HTTP só para testes:** no Android e no Windows o app aceita `http://` (servidor na sua rede local), mas a produção (`fluxeteam.com.br`) é sempre HTTPS. No navegador valem as regras do próprio navegador (uma página `https://` não consegue chamar um servidor `http://`).
- **Permissões (Android):** apenas `INTERNET`. O app não faz backup do token na nuvem (`allowBackup=false`).
- **Identificador do app:** `br.com.fluxeteam.sicapda` (era `com.example.fluxe_app`, o padrão do Flutter). **Não mude depois de publicar**: é por ele que o Android reconhece que um APK novo é uma atualização. Quem instalou uma versão antiga (`com.example.fluxe_app`) fica com os dois apps lado a lado; basta desinstalar o antigo.
- **Ícone, logo e nome:** o app aparece como **SICAPDA** no celular, no Windows e no navegador. A arte do ícone fica em `assets/icon/` (para regenerar os ícones do Android: `dart run flutter_launcher_icons`; o `.ico` do Windows fica em `windows/runner/resources/`) e a logo oficial usada nas telas em `assets/logo/`.

---

## Estrutura do projeto

```
lib/
├── main.dart                  # Ponto de entrada, tema e roteamento login ↔ app
├── core/
│   ├── api_client.dart        # Cliente HTTP (Bearer token, erros, timeout)
│   ├── app_state.dart         # Sessão, token seguro, servidor, tema, alertas
│   ├── theme.dart             # Identidade visual (claro/escuro), cores e fontes
│   ├── layout.dart            # Ponto de corte celular × PC (menu lateral fixo)
│   ├── salvar_arquivo.dart    # Exportação do CSV para a pasta Downloads (Windows)
│   └── format.dart            # Números e datas em pt-BR
├── models/
│   └── models.dart            # Modelos que espelham o JSON da API
├── widgets/
│   ├── common.dart            # Cards, indicadores, estados de carregamento/erro
│   ├── charts.dart            # Gráficos (linha, barras, rosca) com fl_chart
│   ├── sicapda_logo.dart      # Logo oficial do SICAPDA
│   └── page_header.dart       # Cabeçalho, sino e lista de alertas
└── screens/
    ├── login_screen.dart
    ├── app_shell.dart         # Menu lateral (fixo no PC, deslizante no celular) + abas
    ├── painel_screen.dart
    ├── analise_screen.dart
    ├── pessoas_screen.dart
    ├── assistente_screen.dart
    ├── relatorios_screen.dart
    └── configuracoes_screen.dart
assets/fonts/                  # Inter e Sora
assets/icon/                   # Arte do ícone do aplicativo
assets/logo/                   # Logo oficial do SICAPDA (usada no login, no menu e na abertura)
web/                           # Versão web: index.html (tela de carregamento com a logo), manifest, ícones do PWA e sw.js
windows/installer/             # Script do instalador do Windows (Inno Setup) e imagens do assistente
test/                          # Testes + respostas reais da API em test/fixtures/
tool/publicar_app.ps1          # Compila (Android e/ou Windows) e publica no storage/downloads do SystemFluxe
tool/empacotar_windows.ps1     # Gera o SICAPDA-Setup.exe a partir do build do Windows
tool/gerar_icones_web.py       # Gera favicon e ícones do PWA a partir da logo
tool/ci/                       # Teste do APK no emulador (CI): servidor de mentira e roteiro com adb
.github/workflows/build-app.yml  # CI: analisa, testa e compila Android + web + Windows, testa o APK no emulador e publica a Release
```

---

## API utilizada

Todas as rotas ficam no SystemFluxe e, exceto o login, exigem o cabeçalho `Authorization: Bearer <token>`.

| Método | Rota | Descrição |
|---|---|---|
| `POST` | `/api/login` | `{email, senha}` → token (válido por 30 dias) + dados do usuário |
| `GET` | `/api/me` | Perfil do usuário e da empresa |
| `GET` | `/api/painel` | Dados do Painel |
| `GET` | `/api/analise-mensal?mes=YYYY-MM` | Análise mensal |
| `GET` | `/api/pessoas` | Pessoas presentes agora |
| `GET` | `/api/relatorios?de&ate&busca&categoria&pagina` | Registros de acesso paginados |
| `GET` | `/api/relatorios/exportar` | CSV com os mesmos filtros |
| `GET` / `POST` | `/api/assistente` | Informações do assistente / enviar pergunta `{mensagem}` |

Respostas de sucesso trazem `"sucesso": true`; erros trazem `{"sucesso": false, "mensagem": "..."}` com o código HTTP adequado (401, 403, 404, 422, 500). Se o token expirar ou for invalidado, o app volta sozinho para o login.

---

## Testes

```bash
flutter analyze
flutter test
```

Os testes cobrem formatação, cliente HTTP, servidor padrão (celular × web), sessão (inclusive cofre que falha), leitura dos modelos e o fluxo completo do app (login, navegação por todas as telas, logout e tema). Eles usam **respostas reais da API** salvas em `test/fixtures/`, então não precisam de internet nem de servidor.

---

## Principais dependências

| Pacote | Uso |
|---|---|
| [`fl_chart`](https://pub.dev/packages/fl_chart) | Gráficos |
| [`http`](https://pub.dev/packages/http) | Chamadas à API |
| [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) | Guarda o token de acesso de forma criptografada |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Preferências (tema, servidor) |
| [`share_plus`](https://pub.dev/packages/share_plus) | Compartilhar o CSV exportado |
| `flutter_localizations` | Calendário e textos em português |

---

## Problemas comuns

| Sintoma | Causa provável / solução |
|---|---|
| "Não foi possível conectar ao servidor" | Endereço do servidor errado, servidor desligado, ou celular em outra rede. No emulador Android use `10.0.2.2`, não `localhost`. |
| "API não configurada no servidor" | Falta o `API_SECRET` (≥ 32 caracteres) no `config/.env` do SystemFluxe. |
| "E-mail ou senha inválidos" | Use o mesmo e-mail e senha cadastrados na versão web. |
| Volta para o login sozinho | O token expirou (30 dias) ou o usuário foi removido do banco. |
| "App não instalado" / "conflita com um pacote existente" ao atualizar | A versão instalada foi assinada com outra chave (comum com os APKs do GitHub sem a chave própria configurada). Desinstale o SICAPDA e instale de novo; o app só guarda o login. Veja [Assinatura do APK](#assinatura-do-apk-importante-para-atualizações). |
| O Windows mostra "O Windows protegeu o seu computador" ao abrir o instalador | É o SmartScreen: o instalador ainda não tem assinatura digital paga. Clique em **Mais informações → Executar assim mesmo**. |
| O Android avisa sobre "fonte desconhecida" ao instalar | Normal para apps instalados fora da Play Store. Permita a instalação para o navegador ou o gerenciador de arquivos nas configurações do celular. |
| "Não foi possível conectar" só no APK ou só no celular | Veja a linha **"Detalhe técnico"** que o login mostra embaixo da mensagem (ex.: `Failed host lookup` = o celular não achou o endereço; erro de certificado = servidor com HTTPS inválido). Para servidor na sua rede use `http://IP-DO-PC:8000` e confirme que celular e PC estão na mesma rede Wi-Fi. `fluxeteam.com.br` só aceita HTTPS. |
| Versão web fica só com a logo girando / tela em branco | Conexão lenta (o app tem ~4 MB) ou arquivos incompletos em `public/aplicativo/`. Depois de 45 s a tela oferece "Recarregar". Se o site estiver sob um proxy, confira se `canvaskit/canvaskit.wasm` abre (200) e se o `main.dart.js` foi enviado inteiro. |
| Versão web: "Não foi possível conectar ao servidor" ao rodar `flutter run -d chrome` | Aponte o app para o servidor em **Servidor** (a API responde CORS). Se o seu servidor ainda não tem a versão atual do SystemFluxe, atualize: sem os cabeçalhos CORS o navegador bloqueia o login. |
| APK não instala no emulador ("INSTALL_FAILED_NO_MATCHING_ABIS") | Era o APK só ARM das versões antigas; a atual inclui x86_64. Baixe o APK novo. |
| Painel sem dados ou "Sem movimento previsto" | Ainda não há registros nas catracas ou produção cadastrada, ou está fora do expediente. É o mesmo comportamento da web. |
| `git pull` reclama de `pubspec.lock`, `linux/`, `macos/`, `windows/` | São arquivos gerados pelo Flutter. Descarte com `git checkout -- pubspec.lock analysis_options.yaml linux macos windows`, faça o pull e rode `flutter pub get`. |

---

## Equipe

| Nome | Função |
|---|---|
| Davi Gonçalves | Project Owner (PO) / Full-Stack Developer |
| Rian Rafael | Scrum Master / Back-End Developer |
| Rhyan Gabriel | Front-End |
| Beatriz Moreira | Documentação |
| Julia Ferreira | Banco de Dados |

---

© 2026 Fluxe Soluções Inteligentes — Mococa, SP, Brasil
