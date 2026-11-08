# Fake Wise API for local testing. Serves profiles, balances and a statement on 127.0.0.1:9999.
# Accepts only the token "good"; anything else gets 401. Logs statement requests to stderr.
# Usage: see "Test without a real token" in CLAUDE.md.
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime, timedelta, timezone
now = datetime.now(timezone.utc)
def iso(days, h=4): return (now - timedelta(days=days)).replace(hour=h, minute=30, second=0, microsecond=0).strftime('%Y-%m-%dT%H:%M:%S.%fZ')
ST = {"transactions": [
  {"type":"DEBIT","date":iso(0),"amount":{"value":-12.50,"currency":"MYR"},"details":{"type":"CARD","description":"Card transaction of 12.50 MYR issued by Zus Coffee","merchant":{"name":"ZUS COFFEE PENANG","category":"Restaurants"}},"referenceNumber":"CARD-1"},
  {"type":"DEBIT","date":iso(1),"amount":{"value":-25.00,"currency":"MYR"},"details":{"type":"CARD","merchant":{"name":"GRAB*RIDE","category":"Taxicabs"}}},
  {"type":"DEBIT","date":iso(1, 2),"amount":{"value":-9.90,"currency":"MYR"},"details":{"type":"CARD","merchant":{"name":"ZUS COFFEE PENANG","category":"Restaurants"}}},
  {"type":"DEBIT","date":iso(2),"amount":{"value":-48.90,"currency":"MYR"},"details":{"type":"CARD","merchant":{"name":"99 SPEEDMART 1234"}}},
  {"type":"CREDIT","date":iso(3),"amount":{"value":500,"currency":"MYR"},"details":{"type":"DEPOSIT","description":"Received money","senderName":"MUHAMMAD IRFAN"}},
  {"type":"DEBIT","date":iso(4),"amount":{"value":30,"currency":"MYR"},"details":{"type":"TRANSFER","recipient":{"name":"Ali Bin Abu","bankAccount":"123"}}},
  {"type":"DEBIT","date":iso(5),"amount":{"value":-18.00,"currency":"MYR"},"details":{"type":"CARD","merchant":{"name":"KEDAI RUNCIT AMAN","category":None}}},
  {"type":"DEBIT","date":iso(45),"amount":{"value":-15,"currency":"MYR"},"details":{"type":"CARD","merchant":{"name":"Random Shop","category":"Misc Stores"}}},
], "endOfStatementBalance":{"value":365.60,"currency":"MYR"}}
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get('Authorization')
        if auth != 'Bearer good': return self.reply(401, {"error":"unauthorized"})
        p = self.path
        if p == '/v2/profiles': return self.reply(200, [{"id": 98765432101, "type":"BUSINESS"}, {"id": 12345678901, "type":"PERSONAL"}])
        if p.startswith('/v4/profiles/12345678901/balances'): return self.reply(200, [{"id": 111, "currency":"USD"}, {"id": 222333444, "currency":"MYR"}])
        if p.startswith('/v1/profiles/12345678901/balance-statements/222333444/statement.json'):
            sys.stderr.write('STATEMENT ' + p + '\n'); return self.reply(200, ST)
        self.reply(404, {"error": p})
    def reply(self, code, body):
        b = json.dumps(body).encode(); self.send_response(code); self.send_header('Content-Type','application/json'); self.send_header('Content-Length', str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
HTTPServer(('127.0.0.1', 9999), H).serve_forever()
