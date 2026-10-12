#!/usr/bin/env bash
# Teste de fumaça do APK no emulador Android (roda no CI, dentro do emulador já iniciado).
#
#   bash tool/ci/android_smoke.sh caminho/do/SICAPDA.apk [pasta-de-saida]
#
# Se alguma verificação falhar, o teste inteiro roda UMA segunda vez do zero (o app é desinstalado antes): emuladores de
# servidores compartilhados são lentos e às vezes tropeçam por motivos alheios ao app. Só vale o resultado da segunda.
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
TENTATIVA="${3:-1}"
PKG=br.com.fluxeteam.sicapda
mkdir -p "$OUT"
: > "$OUT/resumo.txt"
falhas=0

ok()   { echo "PASS $1"; echo "PASS $1" >> "$OUT/resumo.txt"; }
info() { echo "INFO $1"; echo "INFO $1" >> "$OUT/resumo.txt"; }
erro() { echo "FAIL $1"; echo "FAIL $1" >> "$OUT/resumo.txt"; falhas=$((falhas + 1)); }
# O emulador do CI é lento (2 a 4 núcleos, sem placa de vídeo) e, logo depois de ligar, o Pixel Launcher (o app da
# tela inicial) às vezes trava: o Android mostra "Pixel Launcher isn't responding" e a janela do launcher continua
# com o foco, então a tela do SICAPDA aparece por trás mas os toques nunca chegam nela. Esta função garante que o
# SICAPDA é a janela em foco: se um aviso ANR de outro app estiver na tela, ou se outro app tiver o foco, reinicia
# esse processo e abre o SICAPDA de novo. Devolve 0 se o SICAPDA está em foco, 1 se não deu, 2 se o ANR é do
# próprio SICAPDA (falha de verdade).
JANELAS=$(mktemp)
garantir_app() {
  local t anr pkg
  for t in 1 2 3 4 5; do
    adb shell dumpsys window > "$JANELAS" 2>/dev/null
    anr=$(grep -o 'Application Not Responding: [^} ]*' "$JANELAS" | head -1 | sed 's/.*: //' | tr -d '\r')
    if [ -n "$anr" ]; then
      [ "$anr" = "$PKG" ] && return 2
      info "o Android avisou que $anr não responde (emulador lento); reiniciei esse processo"
      adb shell am force-stop "$anr"; sleep 4
      continue
    fi
    pkg=$(grep -m1 mCurrentFocus "$JANELAS" | tr -d '\r' | sed -nE 's/.*Window\{[0-9a-f]+ u[0-9]+ ([^/ }]+)[/}].*/\1/p')
    [ "$pkg" = "$PKG" ] && return 0
    info "em foco está '${pkg:-nada}' e não o SICAPDA (tentativa $t); abrindo o app de novo"
    case "$pkg" in
      ""|android|NotificationShade|StatusBar) ;;                       # troca de tela em andamento: só espera
      *) adb shell am force-stop "$pkg"; sleep 4 ;;                    # reinicia quem tomou o foco (ex.: launcher travado)
    esac
    adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 8
  done
  return 1
}
# Espera o Android acalmar depois de ligar (launcher e serviços do Google ainda subindo): até ~100 s.
aguardar_calma() {
  local i carga
  for i in $(seq 1 20); do
    carga=$(adb shell cat /proc/loadavg 2>/dev/null | cut -d' ' -f1 | tr -d '\r')
    if [ -n "$carga" ] && awk -v c="$carga" 'BEGIN { exit !(c < 1.5) }'; then
      info "o Android acalmou depois de $((i * 5 - 5)) s (carga $carga)"; return 0
    fi
    sleep 5
  done
  info "o Android ainda estava ocupado depois de 100 s (carga ${carga:-?}); segui assim mesmo"
}
foto() { garantir_app; adb exec-out screencap -p > "$OUT/$1.png"; }
toque() { adb shell input tap "$1" "$2"; }
fim() {
  kill "$MOCK" 2>/dev/null; wait "$MOCK" 2>/dev/null
  if [ "$falhas" -gt 0 ] && [ "$TENTATIVA" -lt 2 ]; then
    echo "$falhas verificação(ões) falharam; tentando mais uma vez, do zero."
    cp "$OUT/resumo.txt" "$OUT/resumo-tentativa1.txt"
    for f in "$OUT"/*.png; do [ -f "$f" ] && mv "$f" "${f%.png}-t1.png"; done
    adb shell am force-stop "$PKG" >/dev/null 2>&1
    adb uninstall "$PKG" >/dev/null 2>&1
    exec bash "$0" "$APK" "$OUT" 2
  fi
  [ "$falhas" -eq 0 ] && rm -f "$OUT"/*-t1.png                      # passou na segunda: as capturas da primeira não servem mais
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    {
      echo "### Teste no emulador Android"
      if [ -f "$OUT/resumo-tentativa1.txt" ]; then
        echo "Primeira tentativa (falhou):"; echo '```'; cat "$OUT/resumo-tentativa1.txt"; echo '```'; echo "Segunda tentativa, do zero:"
      fi
      echo '```'; cat "$OUT/resumo.txt"; echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
  fi
  [ "$falhas" -eq 0 ] && echo "Tudo certo." || echo "$falhas verificação(ões) falharam."
  exit $((falhas > 0 ? 1 : 0))
}

python3 tool/ci/mock_api.py 8000 > "$OUT/mock.log" 2>&1 &
MOCK=$!
sleep 1

adb wait-for-device
adb shell wm dismiss-keyguard >/dev/null 2>&1                     # destrava a tela (sem mandar tecla ao launcher)
aguardar_calma
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
sleep 10
garantir_app; rc=$?
if [ "$rc" -eq 2 ]; then erro "o SICAPDA parou de responder (aviso ANR do Android)"
elif [ "$rc" -ne 0 ]; then erro "o SICAPDA não ficou em primeiro plano depois de aberto (veja as linhas INFO acima)"; fi
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
  garantir_app
  adb exec-out screencap -p > "$ATUAL"
  if read -r nx ny < <(python3 tool/ci/detectar_botao.py "$ATUAL"); then X=$nx; Y=$ny; return 0; fi
  return 1
}

achar_paciente() {                                                  # na abertura o app pode demorar: tenta por uns 45 s
  local t
  for t in 1 2 3 4 5 6; do
    achar_entrar && return 0
    info "tentativa $t: não achei o botão Entrar; janela em foco: $(adb shell dumpsys window 2>/dev/null | grep -m1 mCurrentFocus | tr -d '\r' | sed 's/^ *//')"
    sleep 7
  done
  return 1
}
achar_paciente || { erro "não achei o botão Entrar na tela de abertura (o login não apareceu?)"; fim; }
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
