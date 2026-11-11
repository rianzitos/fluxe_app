#!/usr/bin/env python3
"""Mede, numa captura de tela do chat do Assistente, onde estão a barra de abas e o botão amarelo de enviar.

    python3 tool/ci/detectar_chat.py captura.png abas    # "y" do centro da aba selecionada (pílula amarela embaixo)
    python3 tool/ci/detectar_chat.py captura.png enviar  # "topo base" do botão redondo de enviar (canto direito)

Sai com código 1 se não achar. Só usa as cores da marca (#FFC107), então funciona em qualquer tamanho de tela.
"""
import sys

from PIL import Image


def amarelo(r, g, b):
    return r > 235 and 170 < g < 215 and b < 60


def linhas_amarelas(img, x0, x1, y0, y1, minimo):
    px = img.load()
    return [y for y in range(y0, y1) if sum(1 for x in range(x0, x1, 2) if amarelo(*px[x, y])) * 2 >= minimo]


def aba_selecionada(img):
    """A pílula amarela da aba selecionada (Painel, logo depois do login) fica no quinto da esquerda, embaixo."""
    w, h = img.size
    ys = linhas_amarelas(img, 0, w // 5, int(h * 0.75), h, max(8, w // 40))
    return None if not ys else (ys[0] + ys[-1]) // 2


def botao_enviar(img):
    """O botão de enviar é o único círculo amarelo encostado na direita (a pílula da aba "IA" fica mais ao centro)."""
    w, h = img.size
    ys = linhas_amarelas(img, int(w * 0.83), w, int(h * 0.25), h, max(6, w // 60))
    if not ys:
        return None
    # pega o último bloco contínuo (o botão), ignorando um eventual pedaço amarelo mais acima
    fim = ys[-1]
    inicio = fim
    for y in reversed(ys):
        if inicio - y > 3:
            break
        inicio = y
    return inicio, fim


if __name__ == '__main__':
    imagem = Image.open(sys.argv[1]).convert('RGB')
    if sys.argv[2] == 'abas':
        r = aba_selecionada(imagem)
        if r is None:
            sys.exit(1)
        print(r)
    else:
        r = botao_enviar(imagem)
        if r is None:
            sys.exit(1)
        print(*r)
