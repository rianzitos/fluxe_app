# SICAPDA App (fluxe_app)

Aplicativo mobile (Flutter) do **SICAPDA by Fluxe** — mesmas telas e funcionalidades da versão web
(`SystemFluxe`), lendo o **mesmo banco MySQL** (Workbench) através da API JSON do SystemFluxe.

## Como os dados chegam

```
App Flutter ──HTTPS/JSON──▶ SystemFluxe (PHP, /api/*) ──PDO──▶ MySQL (controle_acesso)
```

O app **não** conecta direto no MySQL: isso exigiria expor o banco na internet e embutir a senha dele
no APK. A API (`app/controllers/ApiController.php`) reutiliza os mesmos models da web
(`Painel`, `Acesso`, `Previsao`, `Assistente`...), sempre filtrando pela empresa do usuário logado.

## Telas

| Tela | Web | Dados |
|---|---|---|
| Login | `/login` | `POST /api/login` (mesmos usuários e senhas da web) |
| Painel | `/painel` | `GET /api/painel` |
| Análise mensal | `/acessos` | `GET /api/analise-mensal?mes=YYYY-MM` |
| Pessoas | `/pessoas` | `GET /api/pessoas` |
| Assistente IA | `/assistente` | `GET/POST /api/assistente` |
| Relatórios (+ CSV) | `/relatorios` | `GET /api/relatorios`, `/api/relatorios/exportar` |
| Configurações | `/configuracoes` | perfil (`/api/me`), tema claro/escuro/sistema, servidor |

## Configurando o servidor (SystemFluxe)

1. Em `SystemFluxe/config/.env` adicione um segredo para os tokens da API:
   `API_SECRET=` (≥ 32 caracteres; gere com `php -r "echo bin2hex(random_bytes(32));"`).
2. Rode o servidor (ex.: `php -S 0.0.0.0:8000 -t public app/routes/web.php`) ou publique normalmente.
3. No app, na tela de login, toque em **Servidor** e informe o endereço:
   - produção: `https://fluxeteam.com.br` (padrão em `lib/core/app_state.dart`)
   - emulador Android → PC: `http://10.0.2.2:8000`
   - celular na mesma rede: `http://IP-DO-PC:8000`

## Rodando

```
flutter pub get
flutter run
flutter analyze && flutter test
```

Os testes usam respostas reais da API salvas em `test/fixtures/`.

## Estrutura

```
lib/
  core/      tema (identidade visual), cliente HTTP, estado/sessão, formatação pt-BR
  models/    modelos do JSON da API
  widgets/   cards, gráficos (fl_chart), cabeçalho/alertas
  screens/   login, shell (menu lateral + abas), painel, análise, pessoas, assistente, relatórios, configurações
```
