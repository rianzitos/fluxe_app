<p align="center">
  <img src="https://fluxeteam.com.br/public/img/logotipo.svg" width="300" align="middle" alt="Logo Fluxe" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://fluxeteam.com.br/public/img/logo_sicapda.png" width="300" align="middle" alt="Logo SICAPDA" />
</p>

# SICAPDA App · fluxe_app

Aplicativo mobile do **SICAPDA** — *Sistema Inteligente de Controle de Acesso e Previsão de Demanda Alimentar*, desenvolvido pela **Fluxe**.

Feito em **Flutter (Dart)**, ele traz para o celular as mesmas telas e funcionalidades da versão web ([SystemFluxe](https://github.com/rianzitos/SystemFluxe)), lendo o **mesmo banco de dados MySQL**: o que muda na web aparece no app, e vice-versa.

📲 **Quer instalar no Android?** Baixe o APK em [fluxeteam.com.br/sicapda#baixar](https://fluxeteam.com.br/sicapda#baixar) (ou veja [como gerar e publicar o APK](#gerar-e-publicar-o-apk)).

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

Outros detalhes: menu lateral escuro igual ao da web, barra de abas inferior, sino com a contagem de alertas, *pull-to-refresh* em todas as telas, tema claro e escuro, e identidade visual idêntica à web (cores `#0D0D0D` / `#FFC107`, fontes **Sora** e **Inter**).

---

## Como rodar

### Pré-requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.12.2`)
- Android Studio (emulador/SDK Android) ou um celular com depuração USB
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
flutter run
```

### 3. Apontar o app para o servidor

Na tela de login, toque em **Servidor** e informe o endereço do SystemFluxe. Depois do login, também dá para trocar em **Configurações → Servidor**.

| Onde o SystemFluxe está | Endereço |
|---|---|
| Produção | `https://fluxeteam.com.br` (padrão do app) |
| Emulador Android → seu PC | `http://10.0.2.2:8000` |
| Celular físico na mesma rede Wi-Fi | `http://IP-DO-SEU-PC:8000` (ex.: `http://192.168.0.10:8000`) |

> O tráfego `http://` (sem SSL) só é permitido em builds de **debug**. Em produção use sempre `https://`.

---

## Gerar e publicar o APK

O instalador do app (APK) é oferecido na página de apresentação do sistema, na seção **Baixar** (`/sicapda#baixar`, atalho `/app`), com botão de download e QR code. Para gerar o APK **não precisa de Android Studio**: o GitHub compila para você.

### Opção 1 — pelo GitHub (recomendado)

O workflow [`Build APK`](.github/workflows/build-apk.yml) analisa, testa e compila o app a cada Pull Request, a cada push na `main`, a cada tag `v*` e também sob demanda (**Actions → Build APK → Run workflow**).

1. No GitHub, abra **Actions → Build APK** e entre na execução mais recente.
2. Em **Artifacts**, baixe `SICAPDA-apk`: um `.zip` com `SICAPDA.apk` e `app.json` (versão, tamanho, SHA-256 e data).
3. Copie os dois arquivos para a pasta `storage/downloads/` do **SystemFluxe**, no servidor. Pronto: a página passa a mostrar versão, tamanho, data e SHA-256, e o botão **Baixar APK** funciona.

Para publicar uma versão "oficial", aumente o `version:` do `pubspec.yaml` (ex.: `1.0.1+2`), faça o merge e crie uma tag. A **Release** do GitHub sai com o APK anexado:

```bash
git tag v1.0.1
git push origin v1.0.1
```

### Opção 2 — no seu computador (Windows)

```powershell
.\tool\publicar_apk.ps1                                    # compila e copia SICAPDA.apk + app.json para ..\SystemFluxe\storage\downloads
.\tool\publicar_apk.ps1 -Destino C:\Projetos\SystemFluxe   # SystemFluxe em outro lugar
.\tool\publicar_apk.ps1 -Servidor https://fluxeteam.com.br # servidor padrão embutido no app
.\tool\publicar_apk.ps1 -SemBuild                          # só publica o APK que já foi compilado
```

Ou à mão: `flutter build apk --release --target-platform android-arm,android-arm64`. O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.

> O APK inclui só as arquiteturas **ARM**, que cobrem todos os celulares e tablets Android e deixam o arquivo bem menor (cerca de 37 MB). Emuladores de PC (x86_64) não rodam esse APK; no emulador use `flutter run`.

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
- **Só HTTPS:** o APK de release bloqueia `http://`. O tráfego sem SSL só funciona em builds de debug (`flutter run`).
- **Permissões:** apenas `INTERNET`.
- **Identificador do app:** hoje é `com.example.fluxe_app` (padrão do Flutter). Se um dia for publicar na Play Store, troque por um identificador próprio **antes** da primeira publicação; depois não dá para mudar.
- **Ícone e nome:** o app aparece como **SICAPDA**. A arte do ícone fica em `assets/icon/`; para regenerar: `dart run flutter_launcher_icons`.

---

## Estrutura do projeto

```
lib/
├── main.dart                  # Ponto de entrada, tema e roteamento login ↔ app
├── core/
│   ├── api_client.dart        # Cliente HTTP (Bearer token, erros, timeout)
│   ├── app_state.dart         # Sessão, token seguro, servidor, tema, alertas
│   ├── theme.dart             # Identidade visual (claro/escuro), cores e fontes
│   └── format.dart            # Números e datas em pt-BR
├── models/
│   └── models.dart            # Modelos que espelham o JSON da API
├── widgets/
│   ├── common.dart            # Cards, indicadores, estados de carregamento/erro
│   ├── charts.dart            # Gráficos (linha, barras, rosca) com fl_chart
│   └── page_header.dart       # Cabeçalho, sino e lista de alertas
└── screens/
    ├── login_screen.dart
    ├── app_shell.dart         # Menu lateral + abas
    ├── painel_screen.dart
    ├── analise_screen.dart
    ├── pessoas_screen.dart
    ├── assistente_screen.dart
    ├── relatorios_screen.dart
    └── configuracoes_screen.dart
assets/fonts/                  # Inter e Sora
assets/icon/                   # Arte do ícone do aplicativo
test/                          # Testes + respostas reais da API em test/fixtures/
tool/publicar_apk.ps1          # Compila o APK e publica no storage/downloads do SystemFluxe
.github/workflows/build-apk.yml  # CI: analisa, testa e compila o APK (artefato SICAPDA-apk)
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

Os testes cobrem formatação, cliente HTTP, leitura dos modelos e o fluxo completo do app (login, navegação por todas as telas, logout e tema). Eles usam **respostas reais da API** salvas em `test/fixtures/`, então não precisam de internet nem de servidor.

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
| O Android avisa sobre "fonte desconhecida" ao instalar | Normal para apps instalados fora da Play Store. Permita a instalação para o navegador ou o gerenciador de arquivos nas configurações do celular. |
| "Não foi possível conectar" só no APK, mas funciona no `flutter run` | O APK de release só aceita `https://`. Use um servidor com SSL ou rode com `flutter run` (debug). |
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
