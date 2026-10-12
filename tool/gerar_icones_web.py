#!/usr/bin/env python3
"""Gera os ícones da versão web (PWA) do SICAPDA a partir da logo oficial dos assets do app.

Uso (na raiz do fluxe_app; precisa do Python 3 e do Pillow: pip install pillow):

    python tool/gerar_icones_web.py

Lê:   assets/icon/icon.png (ícone com fundo escuro), assets/icon/icon_foreground.png (só o emblema),
      assets/logo/sicapda_logo.png (logo horizontal "SICAPDA by FLUXE")
Grava em web/: favicon.png, favicon-32.png, icons/Icon-192.png, Icon-512.png, Icon-maskable-192.png,
      Icon-maskable-512.png, apple-touch-icon.png e splash-logo.png
"""
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
FUNDO = (23, 23, 23, 255)  # #171717, o mesmo fundo do ícone do Android


def emblema() -> Image.Image:
    """O emblema do SICAPDA (escudo + cadeado + garfo + gráfico) recortado rente às bordas."""
    img = Image.open(RAIZ / 'assets/icon/icon_foreground.png').convert('RGBA')
    return img.crop(img.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox())


def com_fundo(tamanho: int, ocupa: float) -> Image.Image:
    """Quadrado sem cantos arredondados (o sistema aplica a máscara dele) com o emblema ocupando
    `ocupa` da largura. Serve para o ícone "maskable" e para o apple-touch-icon."""
    tela = Image.new('RGBA', (tamanho, tamanho), FUNDO)
    e = emblema()
    alvo = round(tamanho * ocupa)
    e = e.resize((alvo, round(e.height * alvo / e.width)), Image.LANCZOS)
    tela.alpha_composite(e, ((tamanho - e.width) // 2, (tamanho - e.height) // 2))
    return tela


def ico_redondo(tamanho: int) -> Image.Image:
    """O ícone padrão do app (quadrado escuro de cantos arredondados) em outro tamanho."""
    return Image.open(RAIZ / 'assets/icon/icon.png').convert('RGBA').resize((tamanho, tamanho), Image.LANCZOS)


def salvar(img: Image.Image, destino: str) -> None:
    caminho = RAIZ / 'web' / destino
    caminho.parent.mkdir(parents=True, exist_ok=True)
    img.save(caminho, optimize=True)
    print(f'  {destino:34s} {img.width}x{img.height}  {caminho.stat().st_size / 1024:.0f} KB')


if __name__ == '__main__':
    print('Gerando ícones da versão web...')
    salvar(ico_redondo(48), 'favicon.png')
    salvar(ico_redondo(32), 'favicon-32.png')
    salvar(ico_redondo(192), 'icons/Icon-192.png')
    salvar(ico_redondo(512), 'icons/Icon-512.png')
    # "maskable": o Android recorta em círculo/gota; o emblema fica na zona segura (~60% do quadrado)
    salvar(com_fundo(192, 0.60), 'icons/Icon-maskable-192.png')
    salvar(com_fundo(512, 0.60), 'icons/Icon-maskable-512.png')
    salvar(com_fundo(180, 0.68), 'icons/apple-touch-icon.png')

    logo = Image.open(RAIZ / 'assets/logo/sicapda_logo.png').convert('RGBA')
    largura = 520
    salvar(logo.resize((largura, round(logo.height * largura / logo.width)), Image.LANCZOS), 'icons/splash-logo.png')
