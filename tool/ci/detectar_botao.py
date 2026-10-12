#!/usr/bin/env python3
"""Acha o botão amarelo "Entrar" numa captura de tela do app e imprime o centro dele ("x y", em pixels).

O botão é a única faixa amarela que ocupa quase a largura toda da tela (a logo também é amarela, mas
estreita). Assim o teste do emulador não depende de coordenadas fixas: funciona em qualquer tamanho de tela.

    python3 tool/ci/detectar_botao.py captura.png
Sai com código 1 se não achar (a tela não é a de login).
"""
import sys

from PIL import Image


def achar(caminho: str):
    img = Image.open(caminho).convert('RGB')
    w, h = img.size
    px = img.load()
    amarelo = lambda r, g, b: r > 235 and 170 < g < 215 and b < 60  # #FFC107 e variações do sombreado
    linhas = []
    for y in range(h):
        n = sum(1 for x in range(0, w, 3) if amarelo(*px[x, y]))
        if n * 3 > w * 0.55:  # a linha é amarela em mais de 55% da largura
            linhas.append(y)
    if not linhas:
        return None
    # primeiro bloco contínuo de linhas
    inicio = fim = linhas[0]
    for y in linhas[1:]:
        if y - fim > 3:
            break
        fim = y
    return w // 2, (inicio + fim) // 2


if __name__ == '__main__':
    r = achar(sys.argv[1])
    if r is None:
        sys.exit(1)
    print(*r)
