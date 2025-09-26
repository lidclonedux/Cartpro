# back/gunicorn_config.py

import os # <--- LINHA DA CORREÇÃO

# Aplica o monkey patch do gevent ANTES de qualquer outra coisa ser importada.
# Isso é crucial para evitar conflitos com threading e outras bibliotecas.
try:
    import gevent.monkey
    gevent.monkey.patch_all()
    print("✅ Gevent monkey patch aplicado com sucesso.")
except ImportError:
    print("⚠️ Gevent não encontrado. O monkey patch não foi aplicado.")

# Configurações que estavam no comando
workers = 4
worker_class = 'gevent'
bind = f"0.0.0.0:{os.environ.get('PORT', 10000)}"
timeout = 120
loglevel = 'debug'
accesslog = '-'
errorlog = '-'
