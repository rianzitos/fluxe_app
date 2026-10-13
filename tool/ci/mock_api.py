#!/usr/bin/env python3
"""Servidor de mentira do SystemFluxe, só para o teste do aplicativo no emulador (CI).

Responde com as respostas REAIS da API que ficam em test/fixtures/ (as mesmas dos testes do app) e escreve
uma linha por requisição na saída ("REQ POST /api/login 200"), que o teste confere depois.

    python3 tool/ci/mock_api.py [porta]        # padrão: 8000, em todas as interfaces (o emulador acessa por 10.0.2.2)

Login aceito: qualquer e-mail com a senha "senha1234".
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

FIXTURES = Path(__file__).resolve().parents[2] / 'test' / 'fixtures'
ROTAS_GET = {
    '/api/me': 'me',
    '/api/painel': 'painel',
    '/api/analise-mensal': 'analise',
    '/api/pessoas': 'pessoas',
    '/api/pessoas/cadastro': 'pessoas_cadastro',
    '/api/pessoas/leituras': 'pessoas_leituras',
    '/api/relatorios': 'relatorios',
    '/api/assistente': 'assistente',
}
ROTAS_ESCRITA_CADASTRO = {
    '/api/pessoas/criar',
    '/api/pessoas/editar',
    '/api/pessoas/ativo',
    '/api/pessoas/cartao',
    '/api/pessoas/cartao/ativo',
    '/api/pessoas/cartao/remover',
}


class Handler(BaseHTTPRequestHandler):
    def _enviar(self, status: int, corpo: bytes, tipo: str = 'application/json; charset=utf-8') -> None:
        self.send_response(status)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(corpo)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(corpo)
        print(f'REQ {self.command} {self.path.split("?")[0]} {status}', flush=True)

    def _fixture(self, nome: str) -> bytes:
        return (FIXTURES / f'{nome}.json').read_bytes()

    def do_GET(self) -> None:
        rota = self.path.split('?')[0]
        if rota in ROTAS_GET:
            self._enviar(200, self._fixture(ROTAS_GET[rota]))
        elif rota == '/api/relatorios/exportar':
            self._enviar(200, 'Nome;Função\n'.encode(), 'text/csv; charset=utf-8')
        else:
            self._enviar(404, json.dumps({'sucesso': False, 'mensagem': 'Rota não encontrada.'}).encode())

    def do_POST(self) -> None:
        rota = self.path.split('?')[0]
        tamanho = int(self.headers.get('Content-Length') or 0)
        try:
            corpo = json.loads(self.rfile.read(tamanho) or b'{}')
        except ValueError:
            corpo = {}
        if rota == '/api/login':
            if corpo.get('senha') == 'senha1234':
                self._enviar(200, self._fixture('login'))
            else:
                self._enviar(401, json.dumps({'sucesso': False, 'mensagem': 'E-mail ou senha inválidos.'}).encode())
        elif rota == '/api/assistente':
            self._enviar(200, self._fixture('assistente_post'))
        elif rota in ROTAS_ESCRITA_CADASTRO:
            # Cadastro de pessoas e cartões: o mock não guarda nada, só confirma (a lista continua a mesma do fixture).
            self._enviar(200, json.dumps({'sucesso': True, 'mensagem': 'Pronto.'}).encode())
        else:
            self._enviar(404, json.dumps({'sucesso': False, 'mensagem': 'Rota não encontrada.'}).encode())

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'Authorization, Content-Type, Accept')
        self.end_headers()

    def log_message(self, *_args) -> None:  # silencia o log padrão (já escrevemos o nosso)
        pass


if __name__ == '__main__':
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    print(f'mock do SystemFluxe em 0.0.0.0:{porta} (fixtures: {FIXTURES})', flush=True)
    ThreadingHTTPServer(('0.0.0.0', porta), Handler).serve_forever()
