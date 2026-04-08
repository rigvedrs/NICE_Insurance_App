import os


class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'nice-insurance-secret-key-2026')
    MYSQL_HOST = os.environ.get('MYSQL_HOST', 'localhost')
    MYSQL_USER = os.environ.get('MYSQL_USER', 'root')
    MYSQL_PASSWORD = os.environ.get('MYSQL_PASSWORD', '')
    MYSQL_DATABASE = 'nice_insurance'
    MYSQL_PORT = int(os.environ.get('MYSQL_PORT', 3306))
    SESSION_PERMANENT = True
    PERMANENT_SESSION_LIFETIME = 1800  # 30 minutes session timeout
