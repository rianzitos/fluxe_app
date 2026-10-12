#!/usr/bin/env python3
"""Acha o botão amarelo "Entrar" numa captura de tela do app e imprime o centro dele ("x y", em pixels).

O botão é o único bloco amarelo ALTO que ocupa quase a largura toda da tela. Outras coisas amarelas na tela
de login não valem: a logo é amarela mas estreita, e a borda do campo em foco (o "anel" amarelo em volta do
e-mail ou da senha) é larga mas fina, com 2 a 3 pixels de altura. Por isso são escolhidos os blocos de linhas
bem amarelas e vence o mais alto, desde que tenha altura de botão. Assim o teste do emulador não depende de
coordenadas fixas: funciona em qualquer tamanho de tela e com qualquer campo em foco.

    python3 tool/ci/detectar_botao.py captura.png
Sai com código 1 se não achar (a tela não é a de login).
"""
import sys

from PIL import Image


def blocos_amarelos(caminho: str):
    """Lista de (inicio, fim) de linhas consecutivas em que mais de 55% da largura é amarela, mais a largura."""
    img = Image.open(caminho).convert('RGB')
    w, h = img.size
    px = img.load()
    amarelo = lambda r, g, b: r > 235 and 170 < g < 215 and b < 60  # #FFC107 e variações do sombreado
    blocos = []
    inicio = fim = None
    for y in range(h):
        n = sum(1 for x in range(0, w, 3) if amarelo(*px[x, y]))
        if n * 3 > w * 0.55:  # a linha é amarela em mais de 55% da largura
            if inicio is None:
                inicio = fim = y
            elif y - fim > 3:  # buraco maior que 3 linhas: começa outro bloco
                blocos.append((inicio, fim))
                inicio = fim = y
            else:
                fim = y
    if inicio is not None:
        blocos.append((inicio, fim))
    return w, blocos


def achar(caminho: str):
    w, blocos = blocos_amarelos(caminho)
    # O botão tem 56 dp de altura (uns 56 px a 160 dpi, uns 150 px a 420 dpi); o anel do campo tem 2 a 3 px.
    minimo = max(24, int(w * 0.04))
    altos = [(f - i, i, f) for i, f in blocos if f - i + 1 >= minimo]
    if not altos:
        return None
    _, inicio, fim = max(altos)
    return w // 2, (inicio + fim) // 2


if __name__ == '__main__':
    r = achar(sys.argv[1])
    if r is None:
        sys.exit(1)
    print(*r)
