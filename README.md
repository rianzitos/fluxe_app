<p align="center">
  <img src="https://fluxeteam.com.br/public/img/logotipo.svg" width="300" align="middle" alt="Logo Fluxe" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="https://fluxeteam.com.br/public/img/logo_sicapda.png" width="300" align="middle" alt="Logo SICAPDA" />
</p>

# SICAPDA App · fluxe_app

Aplicativo mobile do **SICAPDA** — *Sistema Inteligente de Controle de Acesso e Previsão de Demanda Alimentar*, desenvolvido pela **Fluxe**.

Feito em **Flutter (Dart)**, ele traz para o celular as mesmas telas e funcionalidades da versão web ([SystemFluxe](https://github.com/rianzitos/SystemFluxe)), lendo o **mesmo banco de dados MySQL**: o que muda na web aparece no app, e vice-versa.

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
test/                          # Testes + respostas reais da API em test/fixtures/
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
