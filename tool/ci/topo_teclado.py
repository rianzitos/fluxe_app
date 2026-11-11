#!/usr/bin/env python3
"""Lê a saída de `adb shell dumpsys window` (entrada padrão) e imprime o topo do teclado na tela, em pixels.

O Android descreve o espaço que o teclado ocupa como um "InsetsSource" do tipo ime, com o retângulo dele:
    InsetsSource id=... type=ime frame=[0,1430][1080,2400] visible=true      (Android 11 a 15)
    InsetsSource type=ITYPE_IME frame=[0,1430][1080,2400] visible=true       (versões mais antigas)
É a mesma medida que o Flutter recebe como "viewInsets". Sai com código 1 se o teclado não estiver visível.
"""
import re
import sys

melhor = None
for linha in sys.stdin:
    if not re.search(r'type=(ime|ITYPE_IME)\b', linha) or 'visible=true' not in linha:
        continue
    m = re.search(r'frame=\[(-?\d+),(-?\d+)\]\[(-?\d+),(-?\d+)\]', linha)
    if not m:
        continue
    topo, base = int(m.group(2)), int(m.group(4))
    if base > topo > 0 and (melhor is None or topo < melhor):
        melhor = topo
if melhor is None:
    sys.exit(1)
print(melhor)
