#!/usr/bin/env bash
# Teste de fumaça do APK no emulador Android (roda no CI, dentro do emulador já iniciado).
#
#   bash tool/ci/android_smoke.sh caminho/do/SICAPDA.apk [pasta-de-saida]
#
# O que confere, usando o APK de release de verdade (o mesmo que vai para o site):
#   1. instala no Android;
#   2. abre e continua rodando, sem travar (logcat limpo);
#   3. entra com e-mail e senha pelo próprio app, falando com um servidor de mentira (tool/ci/mock_api.py)
#      — prova que o HTTP liberado para testes, o login e o painel funcionam no release (R8/minificado);
#   4. fecha e abre de novo: a sessão continua salva no cofre do Android (o app pede /api/me sozinho).
# As capturas de tela e os logs ficam na pasta de saída (viram artefato do CI).
set -u

APK="${1:?uso: android_smoke.sh caminho/do/SICAPDA.apk [pasta-de-saida]}"
OUT="${2:-smoke}"
PKG=br.com.fluxeteam.sicapda
mkdir -p "$OUT"
: > "$OUT/resumo.txt"
falhas=0

ok()   { echo "PASS $1"; echo "PASS $1" >> "$OUT/resumo.txt"; }
erro() { echo "FAIL $1"; echo "FAIL $1" >> "$OUT/resumo.txt"; falhas=$((falhas + 1)); }
foto() { adb exec-out screencap -p > "$OUT/$1.png"; }
toque() { adb shell input tap "$1" "$2"; }
fim() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    { echo "### Teste no emulador Android"; echo '```'; cat "$OUT/resumo.txt"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
  fi
  kill "$MOCK" 2>/dev/null
  [ "$falhas" -eq 0 ] && echo "Tudo certo." || echo "$falhas verificação(ões) falharam."
  exit $((falhas > 0 ? 1 : 0))
}

python3 tool/ci/mock_api.py 8000 > "$OUT/mock.log" 2>&1 &
MOCK=$!
sleep 1

adb wait-for-device
adb shell input keyevent 82 >/dev/null 2>&1                       # destrava a tela
adb shell settings put secure show_ime_with_hard_keyboard 0 >/dev/null 2>&1
{ echo "Android $(adb shell getprop ro.build.version.release | tr -d '\r') (API $(adb shell getprop ro.build.version.sdk | tr -d '\r')), $(adb shell getprop ro.product.cpu.abi | tr -d '\r')";
  adb shell wm size; adb shell wm density; } | tee "$OUT/aparelho.txt"
read -r W H < <(grep -oE '[0-9]+x[0-9]+' "$OUT/aparelho.txt" | tail -1 | tr 'x' ' ')
DENS=$(grep -oE 'density: [0-9]+' "$OUT/aparelho.txt" | tail -1 | grep -oE '[0-9]+')
DENS=${DENS:-420}
dp() { echo $(( $1 * DENS / 160 )); }                             # dp -> pixels

adb logcat -c

# ── 1) instalar ────────────────────────────────────────────────────────────────
adb install -r "$APK" 2>&1 | tee "$OUT/instalacao.txt"
if grep -q "Success" "$OUT/instalacao.txt"; then
  ok "instalou o APK no Android $(adb shell getprop ro.build.version.release | tr -d '\r')"
else
  erro "não instalou o APK: $(tr '\n' ' ' < "$OUT/instalacao.txt")"
  fim
fi
adb shell dumpsys package "$PKG" | grep -E "versionName|versionCode|minSdk|targetSdk" > "$OUT/pacote.txt"
cat "$OUT/pacote.txt"

# ── 2) abrir ───────────────────────────────────────────────────────────────────
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 15
foto 01-abertura
PID=$(adb shell pidof "$PKG" | tr -d '\r')
if [ -n "$PID" ]; then ok "o app abriu e continua rodando (pid $PID)"; else erro "o app não está rodando depois de abrir"; fi
adb logcat -d > "$OUT/logcat.txt"
if grep -E "FATAL EXCEPTION" "$OUT/logcat.txt" | head -3 | grep -q .; then
  erro "o app travou (veja logcat.txt)"; grep -A12 "FATAL EXCEPTION" "$OUT/logcat.txt" | head -30
else
  ok "nenhum travamento no logcat"
fi

# ── 3) entrar pelo app ──────────────────────────────────────────────────────────
# O botão "Entrar" é o ponto de referência: o resto da tela fica a distâncias fixas (em dp) dele. Como o teclado
# do Android sobe e reorganiza a tela a cada campo tocado, a posição do botão é medida de novo antes de cada toque.
X=0; Y=0
ATUAL=$(mktemp --suffix=.png)                                      # captura de trabalho: não entra na pasta de saída
achar_entrar() {
  adb exec-out screencap -p > "$ATUAL"
  if read -r nx ny < <(python3 tool/ci/detectar_botao.py "$ATUAL"); then X=$nx; Y=$ny; return 0; fi
  return 1
}

achar_entrar || { erro "não achei o botão Entrar na tela de abertura (o login não apareceu?)"; fim; }
ok "tela de login na tela (botão Entrar em ${X},${Y})"

toque "$X" $((Y + $(dp 65)));  sleep 2                             # botão "Servidor": abre o campo do endereço
foto 02-servidor
achar_entrar || { erro "não achei o Entrar depois de abrir o Servidor"; fim; }
toque "$X" $((Y + $(dp 140))); sleep 2                             # campo do endereço do servidor (o teclado sobe)
adb shell input keyevent KEYCODE_MOVE_END
adb shell input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67   # apaga o endereço padrão
adb shell input text 'http://10.0.2.2:8000'                       # 10.0.2.2 = o computador que roda o emulador
sleep 1.5
foto 03-servidor-digitado
adb shell dumpsys input_method 2>/dev/null | grep -E "mInputShown|mImeWindowVis" | head -2 | tee "$OUT/teclado.txt"

achar_entrar || { erro "o botão Entrar sumiu depois de digitar o servidor"; fim; }
toque "$X" $((Y - $(dp 180))); sleep 2                             # campo e-mail
adb shell input text 'teste@fluxe.com'
sleep 1
achar_entrar || { erro "o botão Entrar sumiu depois de digitar o e-mail"; fim; }
toque "$X" $((Y - $(dp 80)));  sleep 2                             # campo senha
adb shell input text 'senha1234'
sleep 1.5
foto 04-formulario
if achar_entrar; then toque "$X" "$Y"; else adb shell input keyevent 66; fi   # botão Entrar (ou ENTER no campo senha)
sleep 10
foto 05-depois-do-login

if grep -q "REQ POST /api/login 200" "$OUT/mock.log"; then ok "o login chegou ao servidor e foi aceito (POST /api/login 200)"; else erro "o app não conseguiu fazer login (veja mock.log e 05-depois-do-login.png)"; fi
if grep -q "REQ GET /api/painel 200" "$OUT/mock.log"; then ok "o painel carregou os dados (GET /api/painel 200)"; else erro "o painel não pediu os dados (GET /api/painel)"; fi
if python3 tool/ci/detectar_botao.py "$OUT/05-depois-do-login.png" >/dev/null 2>&1; then erro "ainda está na tela de login"; else ok "saiu da tela de login"; fi

# ── 4) a sessão fica salva? ───────────────────────────────────────────────────
adb shell am force-stop "$PKG"
sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
sleep 12
foto 06-reaberto
if grep -q "REQ GET /api/me 200" "$OUT/mock.log"; then ok "reabriu já logado: o token estava salvo no cofre do Android (GET /api/me 200)"; else erro "ao reabrir o app não restaurou a sessão"; fi
if python3 tool/ci/detectar_botao.py "$OUT/06-reaberto.png" >/dev/null 2>&1; then erro "voltou para a tela de login ao reabrir"; else ok "reabriu direto no app"; fi

adb logcat -d > "$OUT/logcat.txt"
if grep -E "FATAL EXCEPTION" "$OUT/logcat.txt" | head -1 | grep -q .; then erro "travamento no logcat durante o teste"; fi

fim
