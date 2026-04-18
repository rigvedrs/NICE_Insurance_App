"""
NICE Insurance Web Application - CS-GY 6083 Part II
Flask + MySQL + Bootstrap 5 + Chart.js
"""

import html
import os
import uuid
import functools
from datetime import datetime, timedelta
from decimal import Decimal

import bcrypt
import mysql.connector
from mysql.connector import pooling
from flask import (Flask, render_template, request, redirect, url_for,
                   session, flash, jsonify, g)

from config import Config

# ============================================================
# App Initialization
# ============================================================
app = Flask(__name__)
app.config.from_object(Config)
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(minutes=30)

# ============================================================
# Database Connection Pool
# ============================================================
db_config = {
    'host': app.config['MYSQL_HOST'],
    'user': app.config['MYSQL_USER'],
    'password': app.config['MYSQL_PASSWORD'],
    'database': app.config['MYSQL_DATABASE'],
    'port': app.config['MYSQL_PORT'],
    'autocommit': False,
    'charset': 'utf8mb4',
    'use_unicode': True,
}

try:
    connection_pool = pooling.MySQLConnectionPool(
        pool_name="nice_pool",
        pool_size=5,
        pool_reset_session=True,
        **db_config
    )
except mysql.connector.Error:
    connection_pool = None
    print("WARNING: Could not create connection pool. Database may not be available.")


def get_db():
    """Get a database connection from the pool."""
    if 'db' not in g:
        if connection_pool:
            g.db = connection_pool.get_connection()
        else:
            g.db = mysql.connector.connect(**db_config)
    return g.db


@app.teardown_appcontext
def close_db(exception):
    """Return connection to pool at end of request."""
    db = g.pop('db', None)
    if db is not None:
        try:
            if db.is_connected():
                db.close()
        except Exception:
            pass


def execute_query(query, params=None, fetchone=False, fetchall=False, commit=False, dictionary=True):
    """Execute a parameterized query safely."""
    conn = get_db()
    cursor = conn.cursor(dictionary=dictionary)
    try:
        cursor.execute(query, params or ())
        if commit:
            conn.commit()
            return cursor.lastrowid
        if fetchone:
            return cursor.fetchone()
        if fetchall:
            return cursor.fetchall()
        return cursor
    except mysql.connector.Error as e:
        if commit:
            conn.rollback()
        raise e
    finally:
        if fetchone or fetchall or commit:
            cursor.close()


def execute_proc(proc_name, params=None):
    """Execute a stored procedure."""
    conn = get_db()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.callproc(proc_name, params or ())
        results = []
        for result in cursor.stored_results():
            results.append(result.fetchall())
        conn.commit()
        return results
    except mysql.connector.Error as e:
        conn.rollback()
        raise e
    finally:
        cursor.close()


# ============================================================
# Simple Cache
# ============================================================
_cache = {}
_cache_timestamps = {}
CACHE_TTL = 60  # seconds


def cached(key_prefix, ttl=CACHE_TTL):
    """Simple cache decorator with TTL."""
    def decorator(f):
        @functools.wraps(f)
        def wrapper(*args, **kwargs):
            cache_key = f"{key_prefix}:{args}:{kwargs}"
            now = datetime.now().timestamp()
            if cache_key in _cache and (now - _cache_timestamps.get(cache_key, 0)) < ttl:
                return _cache[cache_key]
            result = f(*args, **kwargs)
            _cache[cache_key] = result
            _cache_timestamps[cache_key] = now
            return result
        return wrapper
    return decorator


def clear_cache(prefix=None):
    """Clear cache entries."""
    global _cache, _cache_timestamps
    if prefix:
        keys_to_delete = [k for k in _cache if k.startswith(prefix)]
        for k in keys_to_delete:
            del _cache[k]
            del _cache_timestamps[k]
    else:
        _cache = {}
        _cache_timestamps = {}


# ============================================================
# Helper: sanitize output
# ============================================================
def sanitize(value):
    """Escape HTML to prevent XSS."""
    if value is None:
        return ''
    return html.escape(str(value))


def decimal_default(obj):
    """JSON serializer for Decimal types."""
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (datetime,)):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


# ============================================================
# Auth Decorators
# ============================================================
def login_required(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('login'))
        # Session timeout check
        last_activity = session.get('last_activity')
        if last_activity:
            last_dt = datetime.fromisoformat(last_activity)
            if datetime.now() - last_dt > timedelta(minutes=30):
                session.clear()
                flash('Session expired. Please log in again.', 'warning')
                return redirect(url_for('login'))
        session['last_activity'] = datetime.now().isoformat()
        return f(*args, **kwargs)
    return wrapper


def customer_required(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('login'))
        if session.get('role') != 'customer':
            flash('Access denied. Customer account required.', 'danger')
            return redirect(url_for('login'))
        session['last_activity'] = datetime.now().isoformat()
        return f(*args, **kwargs)
    return wrapper


def employee_required(f):
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        if 'user_id' not in session:
            flash('Please log in to access this page.', 'warning')
            return redirect(url_for('login'))
        if session.get('role') != 'employee':
            flash('Access denied. Employee account required.', 'danger')
            return redirect(url_for('login'))
        session['last_activity'] = datetime.now().isoformat()
        return f(*args, **kwargs)
    return wrapper


# ============================================================
# CSRF Token
# ============================================================
@app.before_request
def csrf_protect():
    if request.method == "POST":
        token = session.get('csrf_token', None)
        form_token = request.form.get('csrf_token') or request.headers.get('X-CSRF-Token')
        if not token or token != form_token:
            # For AJAX JSON requests, check header
            if request.is_json:
                header_token = request.headers.get('X-CSRF-Token')
                if header_token and header_token == token:
                    return  # Valid AJAX request
            flash('Invalid form submission. Please try again.', 'danger')
            return redirect(request.referrer or url_for('login'))


def generate_csrf_token():
    if 'csrf_token' not in session:
        session['csrf_token'] = str(uuid.uuid4())
    return session['csrf_token']


app.jinja_env.globals['csrf_token'] = generate_csrf_token


# ============================================================
# Context Processor
# ============================================================
@app.context_processor
def inject_globals():
    return {
        'sanitize': sanitize,
        'now': datetime.now(),
    }


# ============================================================
# AUTH ROUTES
# ============================================================
@app.route('/')
def index():
    if 'user_id' in session:
        if session.get('role') == 'employee':
            return redirect(url_for('employee_dashboard'))
        return redirect(url_for('customer_dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'GET':
        return render_template('login.html')

    username = request.form.get('username', '').strip()
    password = request.form.get('password', '').strip()

    if not username or not password:
        flash('Please enter both username and password.', 'danger')
        return render_template('login.html')

    user = execute_query(
        "SELECT * FROM RAH_USER WHERE USERNAME = %s", (username,), fetchone=True
    )

    if not user:
        flash('Invalid username or password.', 'danger')
        return render_template('login.html')

    # Check account lockout
    if user['ACCOUNT_LOCKED']:
        flash('Account is locked due to too many failed attempts. Contact an administrator.', 'danger')
        return render_template('login.html')

    # Verify password
    if bcrypt.checkpw(password.encode('utf-8'), user['PASSWORD_HASH'].encode('utf-8')):
        # Successful login
        execute_query(
            "UPDATE RAH_USER SET FAILED_LOGIN_ATTEMPTS = 0, LAST_LOGIN = NOW() WHERE USER_ID = %s",
            (user['USER_ID'],), commit=True
        )
        # Log successful login
        execute_query(
            "INSERT INTO RAH_LOGIN_HISTORY (USER_ID, LOGIN_DT, IP_ADDRESS, SUCCESS) VALUES (%s, NOW(), %s, 1)",
            (user['USER_ID'], request.remote_addr), commit=True
        )

        session.permanent = True
        session['user_id'] = user['USER_ID']
        session['username'] = user['USERNAME']
        session['role'] = user['ROLE']
        session['cust_id'] = user['CUST_ID']
        session['last_activity'] = datetime.now().isoformat()

        if user['CUST_ID']:
            cust = execute_query(
                "SELECT FIRST_NAME, LAST_NAME FROM RAH_CUSTOMER WHERE CUST_ID = %s",
                (user['CUST_ID'],), fetchone=True
            )
            if cust:
                session['display_name'] = f"{cust['FIRST_NAME']} {cust['LAST_NAME']}"
        else:
            session['display_name'] = user['USERNAME']

        flash(f'Welcome back, {session["display_name"]}!', 'success')
        if user['ROLE'] == 'employee':
            return redirect(url_for('employee_dashboard'))
        return redirect(url_for('customer_dashboard'))
    else:
        # Failed login
        attempts = user['FAILED_LOGIN_ATTEMPTS'] + 1
        locked = 1 if attempts >= 5 else 0
        execute_query(
            "UPDATE RAH_USER SET FAILED_LOGIN_ATTEMPTS = %s, ACCOUNT_LOCKED = %s WHERE USER_ID = %s",
            (attempts, locked, user['USER_ID']), commit=True
        )
        execute_query(
            "INSERT INTO RAH_LOGIN_HISTORY (USER_ID, LOGIN_DT, IP_ADDRESS, SUCCESS) VALUES (%s, NOW(), %s, 0)",
            (user['USER_ID'], request.remote_addr), commit=True
        )
        remaining = 5 - attempts
        if locked:
            flash('Account has been locked due to too many failed attempts.', 'danger')
        else:
            flash(f'Invalid password. {remaining} attempt(s) remaining.', 'danger')
        return render_template('login.html')


@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'GET':
        return render_template('register.html')

    username = request.form.get('username', '').strip()
    email = request.form.get('email', '').strip()
    password = request.form.get('password', '').strip()
    confirm_password = request.form.get('confirm_password', '').strip()
    role = request.form.get('role', 'customer')
    security_question = request.form.get('security_question', '').strip()
    security_answer = request.form.get('security_answer', '').strip()

    # Validation
    errors = []
    if not username or len(username) < 3:
        errors.append('Username must be at least 3 characters.')
    if not email or '@' not in email:
        errors.append('Valid email is required.')
    if not password or len(password) < 6:
        errors.append('Password must be at least 6 characters.')
    if password != confirm_password:
        errors.append('Passwords do not match.')
    if not security_question or not security_answer:
        errors.append('Security question and answer are required.')

    if errors:
        for e in errors:
            flash(e, 'danger')
        return render_template('register.html')

    # Check duplicates
    existing = execute_query(
        "SELECT USER_ID FROM RAH_USER WHERE USERNAME = %s OR EMAIL = %s",
        (username, email), fetchone=True
    )
    if existing:
        flash('Username or email already exists.', 'danger')
        return render_template('register.html')

    # Hash password and security answer
    password_hash = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    answer_hash = bcrypt.hashpw(security_answer.lower().encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    cust_id = None

    if role == 'customer':
        # Create customer record
        first_name = sanitize(request.form.get('first_name', '').strip())
        middle_name = sanitize(request.form.get('middle_name', '').strip()) or None
        last_name = sanitize(request.form.get('last_name', '').strip())
        addr_line1 = sanitize(request.form.get('addr_line1', '').strip())
        addr_line2 = sanitize(request.form.get('addr_line2', '').strip()) or None
        city = sanitize(request.form.get('city', '').strip())
        state = sanitize(request.form.get('state', '').strip())
        zipcode = sanitize(request.form.get('zip', '').strip())
        gender = request.form.get('gender', '').strip() or None
        marital_status = request.form.get('marital_status', 'S').strip()

        if not first_name or not last_name or not addr_line1 or not city or not state or not zipcode:
            flash('All required customer fields must be filled.', 'danger')
            return render_template('register.html')

        # Get next CUST_ID
        max_id = execute_query("SELECT COALESCE(MAX(CUST_ID), 0) + 1 AS next_id FROM RAH_CUSTOMER", fetchone=True)
        cust_id = max_id['next_id']

        conn = get_db()
        try:
            conn.start_transaction()
            cursor = conn.cursor()
            cursor.execute(
                """INSERT INTO RAH_CUSTOMER (CUST_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME,
                   ADDR_LINE1, ADDR_LINE2, CITY, STATE, ZIP, GENDER, MARITAL_STATUS)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (cust_id, first_name, middle_name, last_name, addr_line1, addr_line2,
                 city, state, zipcode, gender, marital_status)
            )
            cursor.execute(
                "INSERT INTO RAH_USER (USERNAME, PASSWORD_HASH, EMAIL, ROLE, CUST_ID, SECURITY_QUESTION, SECURITY_ANSWER_HASH) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (username, password_hash, email, role, cust_id, security_question, answer_hash)
            )
            conn.commit()
            cursor.close()
        except mysql.connector.Error as e:
            conn.rollback()
            flash(f'Registration failed: {str(e)}', 'danger')
            return render_template('register.html')
    else:
        execute_query(
            "INSERT INTO RAH_USER (USERNAME, PASSWORD_HASH, EMAIL, ROLE, CUST_ID, SECURITY_QUESTION, SECURITY_ANSWER_HASH) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (username, password_hash, email, role, None, security_question, answer_hash),
            commit=True
        )

    flash('Registration successful! Please log in.', 'success')
    return redirect(url_for('login'))


@app.route('/logout')
def logout():
    session.clear()
    flash('You have been logged out.', 'info')
    return redirect(url_for('login'))


@app.route('/reset-password', methods=['GET', 'POST'])
def reset_password():
    if request.method == 'GET':
        return render_template('login.html', show_reset=True)

    username = request.form.get('username', '').strip()
    security_answer = request.form.get('security_answer', '').strip()
    new_password = request.form.get('new_password', '').strip()

    if not username or not security_answer or not new_password:
        flash('All fields are required for password reset.', 'danger')
        return render_template('login.html', show_reset=True)

    user = execute_query(
        "SELECT * FROM RAH_USER WHERE USERNAME = %s", (username,), fetchone=True
    )
    if not user:
        flash('User not found.', 'danger')
        return render_template('login.html', show_reset=True)

    if bcrypt.checkpw(security_answer.lower().encode('utf-8'), user['SECURITY_ANSWER_HASH'].encode('utf-8')):
        new_hash = bcrypt.hashpw(new_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        execute_query(
            "UPDATE RAH_USER SET PASSWORD_HASH = %s, FAILED_LOGIN_ATTEMPTS = 0, ACCOUNT_LOCKED = 0 WHERE USER_ID = %s",
            (new_hash, user['USER_ID']), commit=True
        )
        # Log reset
        token = str(uuid.uuid4())
        execute_query(
            "INSERT INTO RAH_PASSWORD_RESET (USER_ID, RESET_TOKEN, EXPIRES_AT, USED) VALUES (%s, %s, NOW(), 1)",
            (user['USER_ID'], token), commit=True
        )
        flash('Password reset successful! Please log in with your new password.', 'success')
        return redirect(url_for('login'))
    else:
        flash('Incorrect security answer.', 'danger')
        return render_template('login.html', show_reset=True)


@app.route('/get-security-question', methods=['POST'])
def get_security_question():
    username = request.form.get('username', '').strip()
    if not username:
        return jsonify({'error': 'Username required'}), 400
    user = execute_query(
        "SELECT SECURITY_QUESTION FROM RAH_USER WHERE USERNAME = %s", (username,), fetchone=True
    )
    if user:
        return jsonify({'question': user['SECURITY_QUESTION']})
    return jsonify({'error': 'User not found'}), 404


# ============================================================
# CUSTOMER ROUTES
# ============================================================
@app.route('/customer/dashboard')
@customer_required
def customer_dashboard():
    cust_id = session['cust_id']

    # Summary stats
    home_policies = execute_query(
        "SELECT COUNT(*) as cnt FROM RAH_HOME_POLICY WHERE CUST_ID = %s AND HPOLICY_STATUS = 'C'",
        (cust_id,), fetchone=True
    )
    auto_policies = execute_query(
        "SELECT COUNT(*) as cnt FROM RAH_AUTO_POLICY WHERE CUST_ID = %s AND APOLICY_STATUS = 'C'",
        (cust_id,), fetchone=True
    )
    total_premium = execute_query(
        "SELECT fn_total_premium(%s) as total", (cust_id,), fetchone=True
    )
    outstanding = execute_query(
        "SELECT fn_outstanding_balance(%s) as balance", (cust_id,), fetchone=True
    )

    # Total payments made
    home_paid = execute_query(
        """SELECT COALESCE(SUM(hp.HPAYMENT_AMT), 0) as total FROM RAH_HOME_PAYMENT hp
           JOIN RAH_HOME_INVOICE hi ON hp.HINVOICE_ID = hi.HINVOICE_ID
           JOIN RAH_HOME_POLICY hpol ON hi.HPOLICY_ID = hpol.HPOLICY_ID
           WHERE hpol.CUST_ID = %s""",
        (cust_id,), fetchone=True
    )
    auto_paid = execute_query(
        """SELECT COALESCE(SUM(ap.APAYMENT_AMT), 0) as total FROM RAH_AUTO_PAYMENT ap
           JOIN RAH_AUTO_INVOICE ai ON ap.AINVOICE_ID = ai.AINVOICE_ID
           JOIN RAH_AUTO_POLICY apol ON ai.APOLICY_ID = apol.APOLICY_ID
           WHERE apol.CUST_ID = %s""",
        (cust_id,), fetchone=True
    )

    # Recent invoices
    recent_invoices = execute_query(
        """(SELECT 'Home' as type, HINVOICE_ID as id, HINVOICE_DT as inv_date,
            HINVOICE_DUE_DT as due_date, HINVOICE_AMT as amount, hi.HPOLICY_ID as policy_id
           FROM RAH_HOME_INVOICE hi
           JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
           WHERE hp.CUST_ID = %s)
           UNION ALL
           (SELECT 'Auto' as type, ai.AINVOICE_ID as id, ai.AINVOICE_DT as inv_date,
            ai.AINVOICE_DUE_DT as due_date, ai.AINVOICE_AMT as amount, ai.APOLICY_ID as policy_id
           FROM RAH_AUTO_INVOICE ai
           JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
           WHERE ap.CUST_ID = %s)
           ORDER BY inv_date DESC LIMIT 10""",
        (cust_id, cust_id), fetchall=True
    )

    stats = {
        'active_policies': (home_policies['cnt'] or 0) + (auto_policies['cnt'] or 0),
        'total_premium': float(total_premium['total'] or 0),
        'outstanding_balance': float(outstanding['balance'] or 0),
        'total_paid': float(home_paid['total'] or 0) + float(auto_paid['total'] or 0),
    }

    return render_template('customer/dashboard.html', stats=stats, recent_invoices=recent_invoices)


@app.route('/customer/policies')
@customer_required
def customer_policies():
    cust_id = session['cust_id']

    home_policies = execute_query(
        """SELECT hp.*, h.HOME_TYPE, h.HOME_PURCHASE_VAL, h.HOME_AREA_SQFT,
           h.AUTO_FIRE_NOTIF, h.HOME_SECURITY_SYS, h.SWIMMING_POOL, h.BASEMENT
           FROM RAH_HOME_POLICY hp
           LEFT JOIN RAH_HOME h ON hp.HPOLICY_ID = h.HPOLICY_ID
           WHERE hp.CUST_ID = %s ORDER BY hp.HPOLICY_START_DT DESC""",
        (cust_id,), fetchall=True
    )

    auto_policies = execute_query(
        """SELECT ap.*, COUNT(v.VEHICLE_ID) as vehicle_count
           FROM RAH_AUTO_POLICY ap
           LEFT JOIN RAH_VEHICLE v ON ap.APOLICY_ID = v.APOLICY_ID
           WHERE ap.CUST_ID = %s
           GROUP BY ap.APOLICY_ID ORDER BY ap.APOLICY_START_DT DESC""",
        (cust_id,), fetchall=True
    )

    return render_template('customer/policies.html', home_policies=home_policies, auto_policies=auto_policies)


@app.route('/customer/invoices')
@customer_required
def customer_invoices():
    cust_id = session['cust_id']

    home_invoices = execute_query(
        """SELECT hi.*, hp.HPOLICY_ID, hp.HPOLICY_STATUS,
           COALESCE(SUM(hpay.HPAYMENT_AMT), 0) as paid_amount
           FROM RAH_HOME_INVOICE hi
           JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
           LEFT JOIN RAH_HOME_PAYMENT hpay ON hi.HINVOICE_ID = hpay.HINVOICE_ID
           WHERE hp.CUST_ID = %s
           GROUP BY hi.HINVOICE_ID ORDER BY hi.HINVOICE_DT DESC""",
        (cust_id,), fetchall=True
    )

    auto_invoices = execute_query(
        """SELECT ai.*, ap.APOLICY_ID, ap.APOLICY_STATUS,
           COALESCE(SUM(apay.APAYMENT_AMT), 0) as paid_amount
           FROM RAH_AUTO_INVOICE ai
           JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
           LEFT JOIN RAH_AUTO_PAYMENT apay ON ai.AINVOICE_ID = apay.AINVOICE_ID
           WHERE ap.CUST_ID = %s
           GROUP BY ai.AINVOICE_ID ORDER BY ai.AINVOICE_DT DESC""",
        (cust_id,), fetchall=True
    )

    return render_template('customer/invoices.html', home_invoices=home_invoices, auto_invoices=auto_invoices)


@app.route('/customer/payments', methods=['GET', 'POST'])
@customer_required
def customer_payments():
    cust_id = session['cust_id']

    if request.method == 'POST':
        payment_type = request.form.get('payment_type')
        invoice_id = request.form.get('invoice_id')
        amount = request.form.get('amount')
        method = request.form.get('payment_method')

        try:
            execute_proc('sp_process_payment', (payment_type, int(invoice_id), float(amount), method, datetime.now().strftime('%Y-%m-%d')))
            clear_cache()
            flash('Payment processed successfully!', 'success')
        except Exception as e:
            flash(f'Payment failed: {str(e)}', 'danger')
        return redirect(url_for('customer_payments'))

    # Get unpaid invoices
    home_invoices = execute_query(
        """SELECT hi.HINVOICE_ID as invoice_id, 'home' as type, hi.HINVOICE_AMT as amount,
           hi.HINVOICE_DUE_DT as due_date, hi.HPOLICY_ID as policy_id,
           hi.HINVOICE_AMT - COALESCE(SUM(hpay.HPAYMENT_AMT), 0) as remaining
           FROM RAH_HOME_INVOICE hi
           JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
           LEFT JOIN RAH_HOME_PAYMENT hpay ON hi.HINVOICE_ID = hpay.HINVOICE_ID
           WHERE hp.CUST_ID = %s
           GROUP BY hi.HINVOICE_ID
           HAVING remaining > 0
           ORDER BY hi.HINVOICE_DUE_DT""",
        (cust_id,), fetchall=True
    )

    auto_invoices = execute_query(
        """SELECT ai.AINVOICE_ID as invoice_id, 'auto' as type, ai.AINVOICE_AMT as amount,
           ai.AINVOICE_DUE_DT as due_date, ai.APOLICY_ID as policy_id,
           ai.AINVOICE_AMT - COALESCE(SUM(apay.APAYMENT_AMT), 0) as remaining
           FROM RAH_AUTO_INVOICE ai
           JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
           LEFT JOIN RAH_AUTO_PAYMENT apay ON ai.AINVOICE_ID = apay.AINVOICE_ID
           WHERE ap.CUST_ID = %s
           GROUP BY ai.AINVOICE_ID
           HAVING remaining > 0
           ORDER BY ai.AINVOICE_DUE_DT""",
        (cust_id,), fetchall=True
    )

    # Payment history
    payments = execute_query(
        """(SELECT 'Home' as type, hp.HPAYMENT_ID as id, hp.HPAYMENT_DT as pay_date,
            hp.HPAYMENT_AMT as amount, hp.HPAYMENT_METHOD as method, hp.HINVOICE_ID as invoice_id
           FROM RAH_HOME_PAYMENT hp
           JOIN RAH_HOME_INVOICE hi ON hp.HINVOICE_ID = hi.HINVOICE_ID
           JOIN RAH_HOME_POLICY hpol ON hi.HPOLICY_ID = hpol.HPOLICY_ID
           WHERE hpol.CUST_ID = %s)
           UNION ALL
           (SELECT 'Auto' as type, ap.APAYMENT_ID as id, ap.APAYMENT_DT as pay_date,
            ap.APAYMENT_AMT as amount, ap.APAYMENT_METHOD as method, ap.AINVOICE_ID as invoice_id
           FROM RAH_AUTO_PAYMENT ap
           JOIN RAH_AUTO_INVOICE ai ON ap.AINVOICE_ID = ai.AINVOICE_ID
           JOIN RAH_AUTO_POLICY apol ON ai.APOLICY_ID = apol.APOLICY_ID
           WHERE apol.CUST_ID = %s)
           ORDER BY pay_date DESC""",
        (cust_id, cust_id), fetchall=True
    )

    unpaid = list(home_invoices or []) + list(auto_invoices or [])
    return render_template('customer/payments.html', unpaid_invoices=unpaid, payments=payments)


@app.route('/customer/vehicles')
@customer_required
def customer_vehicles():
    cust_id = session['cust_id']
    vehicles = execute_query(
        """SELECT v.*, ap.APOLICY_ID, ap.APOLICY_STATUS
           FROM RAH_VEHICLE v
           JOIN RAH_AUTO_POLICY ap ON v.APOLICY_ID = ap.APOLICY_ID
           WHERE ap.CUST_ID = %s ORDER BY v.VEHICLE_YEAR DESC""",
        (cust_id,), fetchall=True
    )

    # Get drivers for each vehicle
    vehicle_drivers = {}
    for v in vehicles:
        drivers = execute_query(
            """SELECT d.* FROM RAH_DRIVER d
               JOIN RAH_VEHICLE_DRIVER vd ON d.DRIVER_ID = vd.DRIVER_ID
               WHERE vd.VEHICLE_ID = %s""",
            (v['VEHICLE_ID'],), fetchall=True
        )
        vehicle_drivers[v['VEHICLE_ID']] = drivers

    return render_template('customer/vehicles.html', vehicles=vehicles, vehicle_drivers=vehicle_drivers)


@app.route('/customer/profile', methods=['GET', 'POST'])
@customer_required
def customer_profile():
    cust_id = session['cust_id']

    if request.method == 'POST':
        addr_line1 = sanitize(request.form.get('addr_line1', '').strip())
        addr_line2 = sanitize(request.form.get('addr_line2', '').strip()) or None
        city = sanitize(request.form.get('city', '').strip())
        state = sanitize(request.form.get('state', '').strip())
        zipcode = sanitize(request.form.get('zip', '').strip())

        try:
            execute_query(
                """UPDATE RAH_CUSTOMER SET ADDR_LINE1 = %s, ADDR_LINE2 = %s,
                   CITY = %s, STATE = %s, ZIP = %s WHERE CUST_ID = %s""",
                (addr_line1, addr_line2, city, state, zipcode, cust_id), commit=True
            )
            flash('Profile updated successfully!', 'success')
        except Exception as e:
            flash(f'Update failed: {str(e)}', 'danger')
        return redirect(url_for('customer_profile'))

    customer = execute_query(
        "SELECT * FROM RAH_CUSTOMER WHERE CUST_ID = %s", (cust_id,), fetchone=True
    )
    user = execute_query(
        "SELECT USERNAME, EMAIL, CREATED_AT, LAST_LOGIN FROM RAH_USER WHERE CUST_ID = %s",
        (cust_id,), fetchone=True
    )
    cust_types = execute_query(
        "SELECT CUST_TYPE FROM RAH_CUST_TYPE WHERE CUST_ID = %s", (cust_id,), fetchall=True
    )

    return render_template('customer/profile.html', customer=customer, user=user, cust_types=cust_types)


# ============================================================
# EMPLOYEE ROUTES
# ============================================================
@app.route('/employee/dashboard')
@employee_required
def employee_dashboard():
    total_customers = execute_query("SELECT COUNT(*) as cnt FROM RAH_CUSTOMER", fetchone=True)
    active_home = execute_query("SELECT COUNT(*) as cnt FROM RAH_HOME_POLICY WHERE HPOLICY_STATUS = 'C'", fetchone=True)
    active_auto = execute_query("SELECT COUNT(*) as cnt FROM RAH_AUTO_POLICY WHERE APOLICY_STATUS = 'C'", fetchone=True)

    total_revenue_home = execute_query("SELECT COALESCE(SUM(HPAYMENT_AMT), 0) as total FROM RAH_HOME_PAYMENT", fetchone=True)
    total_revenue_auto = execute_query("SELECT COALESCE(SUM(APAYMENT_AMT), 0) as total FROM RAH_AUTO_PAYMENT", fetchone=True)

    outstanding_home = execute_query(
        """SELECT COALESCE(SUM(hi.HINVOICE_AMT), 0) - COALESCE((SELECT SUM(HPAYMENT_AMT) FROM RAH_HOME_PAYMENT), 0) as total
           FROM RAH_HOME_INVOICE hi""", fetchone=True
    )
    outstanding_auto = execute_query(
        """SELECT COALESCE(SUM(ai.AINVOICE_AMT), 0) - COALESCE((SELECT SUM(APAYMENT_AMT) FROM RAH_AUTO_PAYMENT), 0) as total
           FROM RAH_AUTO_INVOICE ai""", fetchone=True
    )

    # Recent audit entries
    recent_audit = execute_query(
        "SELECT * FROM RAH_POLICY_AUDIT ORDER BY CHANGED_AT DESC LIMIT 10", fetchall=True
    )

    stats = {
        'total_customers': total_customers['cnt'],
        'active_policies': (active_home['cnt'] or 0) + (active_auto['cnt'] or 0),
        'total_revenue': float(total_revenue_home['total'] or 0) + float(total_revenue_auto['total'] or 0),
        'outstanding': float(outstanding_home['total'] or 0) + float(outstanding_auto['total'] or 0),
    }

    return render_template('employee/dashboard.html', stats=stats, recent_audit=recent_audit)


@app.route('/employee/customers', methods=['GET'])
@employee_required
def employee_customers():
    search = request.args.get('search', '').strip()
    page = int(request.args.get('page', 1))
    per_page = 15
    offset = (page - 1) * per_page

    if search:
        search_param = f"%{search}%"
        customers = execute_query(
            """SELECT c.*, GROUP_CONCAT(ct.CUST_TYPE) as types
               FROM RAH_CUSTOMER c
               LEFT JOIN RAH_CUST_TYPE ct ON c.CUST_ID = ct.CUST_ID
               WHERE c.FIRST_NAME LIKE %s OR c.LAST_NAME LIKE %s OR c.CITY LIKE %s OR c.STATE LIKE %s
               GROUP BY c.CUST_ID ORDER BY c.CUST_ID LIMIT %s OFFSET %s""",
            (search_param, search_param, search_param, search_param, per_page, offset), fetchall=True
        )
        total = execute_query(
            """SELECT COUNT(DISTINCT c.CUST_ID) as cnt FROM RAH_CUSTOMER c
               WHERE c.FIRST_NAME LIKE %s OR c.LAST_NAME LIKE %s OR c.CITY LIKE %s OR c.STATE LIKE %s""",
            (search_param, search_param, search_param, search_param), fetchone=True
        )
    else:
        customers = execute_query(
            """SELECT c.*, GROUP_CONCAT(ct.CUST_TYPE) as types
               FROM RAH_CUSTOMER c
               LEFT JOIN RAH_CUST_TYPE ct ON c.CUST_ID = ct.CUST_ID
               GROUP BY c.CUST_ID ORDER BY c.CUST_ID LIMIT %s OFFSET %s""",
            (per_page, offset), fetchall=True
        )
        total = execute_query("SELECT COUNT(*) as cnt FROM RAH_CUSTOMER", fetchone=True)

    total_pages = max(1, (total['cnt'] + per_page - 1) // per_page)
    return render_template('employee/customers.html', customers=customers, page=page,
                         total_pages=total_pages, search=search)


@app.route('/employee/customers/add', methods=['POST'])
@employee_required
def employee_add_customer():
    first_name = sanitize(request.form.get('first_name', '').strip())
    middle_name = sanitize(request.form.get('middle_name', '').strip()) or None
    last_name = sanitize(request.form.get('last_name', '').strip())
    addr_line1 = sanitize(request.form.get('addr_line1', '').strip())
    addr_line2 = sanitize(request.form.get('addr_line2', '').strip()) or None
    city = sanitize(request.form.get('city', '').strip())
    state = sanitize(request.form.get('state', '').strip())
    zipcode = sanitize(request.form.get('zip', '').strip())
    gender = request.form.get('gender') or None
    marital_status = request.form.get('marital_status', 'S')
    cust_types = request.form.getlist('cust_types')

    try:
        max_id = execute_query("SELECT COALESCE(MAX(CUST_ID), 0) + 1 AS nid FROM RAH_CUSTOMER", fetchone=True)
        new_id = max_id['nid']

        conn = get_db()
        conn.start_transaction()
        cursor = conn.cursor()
        cursor.execute(
            """INSERT INTO RAH_CUSTOMER (CUST_ID, FIRST_NAME, MIDDLE_NAME, LAST_NAME,
               ADDR_LINE1, ADDR_LINE2, CITY, STATE, ZIP, GENDER, MARITAL_STATUS)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
            (new_id, first_name, middle_name, last_name, addr_line1, addr_line2,
             city, state, zipcode, gender, marital_status)
        )
        for ct in cust_types:
            cursor.execute("INSERT INTO RAH_CUST_TYPE (CUST_ID, CUST_TYPE) VALUES (%s, %s)", (new_id, ct))
        conn.commit()
        cursor.close()
        clear_cache()
        flash(f'Customer #{new_id} created successfully!', 'success')
    except Exception as e:
        flash(f'Error creating customer: {str(e)}', 'danger')
    return redirect(url_for('employee_customers'))


@app.route('/employee/customers/edit/<int:cust_id>', methods=['POST'])
@employee_required
def employee_edit_customer(cust_id):
    first_name = sanitize(request.form.get('first_name', '').strip())
    middle_name = sanitize(request.form.get('middle_name', '').strip()) or None
    last_name = sanitize(request.form.get('last_name', '').strip())
    addr_line1 = sanitize(request.form.get('addr_line1', '').strip())
    addr_line2 = sanitize(request.form.get('addr_line2', '').strip()) or None
    city = sanitize(request.form.get('city', '').strip())
    state = sanitize(request.form.get('state', '').strip())
    zipcode = sanitize(request.form.get('zip', '').strip())
    gender = request.form.get('gender') or None
    marital_status = request.form.get('marital_status', 'S')

    try:
        execute_query(
            """UPDATE RAH_CUSTOMER SET FIRST_NAME=%s, MIDDLE_NAME=%s, LAST_NAME=%s,
               ADDR_LINE1=%s, ADDR_LINE2=%s, CITY=%s, STATE=%s, ZIP=%s,
               GENDER=%s, MARITAL_STATUS=%s WHERE CUST_ID=%s""",
            (first_name, middle_name, last_name, addr_line1, addr_line2,
             city, state, zipcode, gender, marital_status, cust_id), commit=True
        )
        clear_cache()
        flash(f'Customer #{cust_id} updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating customer: {str(e)}', 'danger')
    return redirect(url_for('employee_customers'))


@app.route('/employee/customers/delete/<int:cust_id>', methods=['POST'])
@employee_required
def employee_delete_customer(cust_id):
    try:
        execute_query("DELETE FROM RAH_CUSTOMER WHERE CUST_ID = %s", (cust_id,), commit=True)
        clear_cache()
        flash(f'Customer #{cust_id} deleted successfully.', 'success')
    except Exception as e:
        flash(f'Error deleting customer: {str(e)}', 'danger')
    return redirect(url_for('employee_customers'))


# ---- Employee Policies ----
@app.route('/employee/policies', methods=['GET'])
@employee_required
def employee_policies():
    policy_type = request.args.get('type', 'home')
    search = request.args.get('search', '').strip()

    if policy_type == 'home':
        if search:
            sp = f"%{search}%"
            policies = execute_query(
                """SELECT hp.*, c.FIRST_NAME, c.LAST_NAME,
                   h.HOME_TYPE, h.HOME_PURCHASE_VAL
                   FROM RAH_HOME_POLICY hp
                   JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID
                   LEFT JOIN RAH_HOME h ON hp.HPOLICY_ID = h.HPOLICY_ID
                   WHERE c.FIRST_NAME LIKE %s OR c.LAST_NAME LIKE %s OR CAST(hp.HPOLICY_ID AS CHAR) LIKE %s
                   ORDER BY hp.HPOLICY_START_DT DESC""",
                (sp, sp, sp), fetchall=True
            )
        else:
            policies = execute_query(
                """SELECT hp.*, c.FIRST_NAME, c.LAST_NAME,
                   h.HOME_TYPE, h.HOME_PURCHASE_VAL
                   FROM RAH_HOME_POLICY hp
                   JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID
                   LEFT JOIN RAH_HOME h ON hp.HPOLICY_ID = h.HPOLICY_ID
                   ORDER BY hp.HPOLICY_START_DT DESC""", fetchall=True
            )
    else:
        if search:
            sp = f"%{search}%"
            policies = execute_query(
                """SELECT ap.*, c.FIRST_NAME, c.LAST_NAME,
                   COUNT(v.VEHICLE_ID) as vehicle_count
                   FROM RAH_AUTO_POLICY ap
                   JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
                   LEFT JOIN RAH_VEHICLE v ON ap.APOLICY_ID = v.APOLICY_ID
                   WHERE c.FIRST_NAME LIKE %s OR c.LAST_NAME LIKE %s OR CAST(ap.APOLICY_ID AS CHAR) LIKE %s
                   GROUP BY ap.APOLICY_ID ORDER BY ap.APOLICY_START_DT DESC""",
                (sp, sp, sp), fetchall=True
            )
        else:
            policies = execute_query(
                """SELECT ap.*, c.FIRST_NAME, c.LAST_NAME,
                   COUNT(v.VEHICLE_ID) as vehicle_count
                   FROM RAH_AUTO_POLICY ap
                   JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
                   LEFT JOIN RAH_VEHICLE v ON ap.APOLICY_ID = v.APOLICY_ID
                   GROUP BY ap.APOLICY_ID ORDER BY ap.APOLICY_START_DT DESC""",
                fetchall=True
            )

    customers = execute_query("SELECT CUST_ID, FIRST_NAME, LAST_NAME FROM RAH_CUSTOMER ORDER BY LAST_NAME", fetchall=True)
    return render_template('employee/policies.html', policies=policies, policy_type=policy_type,
                         customers=customers, search=search)


@app.route('/employee/policies/add', methods=['POST'])
@employee_required
def employee_add_policy():
    policy_type = request.form.get('policy_type')
    cust_id = int(request.form.get('cust_id'))
    start_dt = request.form.get('start_date')
    end_dt = request.form.get('end_date')
    premium = float(request.form.get('premium'))
    status = request.form.get('status', 'C')

    try:
        if policy_type == 'home':
            max_id = execute_query("SELECT COALESCE(MAX(HPOLICY_ID), 0)+1 AS nid FROM RAH_HOME_POLICY", fetchone=True)
            execute_query(
                """INSERT INTO RAH_HOME_POLICY (HPOLICY_ID, HPOLICY_START_DT, HPOLICY_END_DT,
                   HPREMIUM_AMT, HPOLICY_STATUS, CUST_ID) VALUES (%s,%s,%s,%s,%s,%s)""",
                (max_id['nid'], start_dt, end_dt, premium, status, cust_id), commit=True
            )
            # Ensure customer type exists
            existing = execute_query(
                "SELECT 1 FROM RAH_CUST_TYPE WHERE CUST_ID=%s AND CUST_TYPE='H'", (cust_id,), fetchone=True
            )
            if not existing:
                execute_query("INSERT INTO RAH_CUST_TYPE VALUES (%s, 'H')", (cust_id,), commit=True)
        else:
            max_id = execute_query("SELECT COALESCE(MAX(APOLICY_ID), 0)+1 AS nid FROM RAH_AUTO_POLICY", fetchone=True)
            execute_query(
                """INSERT INTO RAH_AUTO_POLICY (APOLICY_ID, APOLICY_START_DT, APOLICY_END_DT,
                   APREMIUM_AMT, APOLICY_STATUS, CUST_ID) VALUES (%s,%s,%s,%s,%s,%s)""",
                (max_id['nid'], start_dt, end_dt, premium, status, cust_id), commit=True
            )
            existing = execute_query(
                "SELECT 1 FROM RAH_CUST_TYPE WHERE CUST_ID=%s AND CUST_TYPE='A'", (cust_id,), fetchone=True
            )
            if not existing:
                execute_query("INSERT INTO RAH_CUST_TYPE VALUES (%s, 'A')", (cust_id,), commit=True)

        clear_cache()
        flash('Policy created successfully!', 'success')
    except Exception as e:
        flash(f'Error creating policy: {str(e)}', 'danger')
    return redirect(url_for('employee_policies', type=policy_type))


@app.route('/employee/policies/edit/<policy_type>/<int:policy_id>', methods=['POST'])
@employee_required
def employee_edit_policy(policy_type, policy_id):
    start_dt = request.form.get('start_date')
    end_dt = request.form.get('end_date')
    premium = float(request.form.get('premium'))
    status = request.form.get('status')

    try:
        if policy_type == 'home':
            execute_query(
                """UPDATE RAH_HOME_POLICY SET HPOLICY_START_DT=%s, HPOLICY_END_DT=%s,
                   HPREMIUM_AMT=%s, HPOLICY_STATUS=%s WHERE HPOLICY_ID=%s""",
                (start_dt, end_dt, premium, status, policy_id), commit=True
            )
        else:
            execute_query(
                """UPDATE RAH_AUTO_POLICY SET APOLICY_START_DT=%s, APOLICY_END_DT=%s,
                   APREMIUM_AMT=%s, APOLICY_STATUS=%s WHERE APOLICY_ID=%s""",
                (start_dt, end_dt, premium, status, policy_id), commit=True
            )
        clear_cache()
        flash('Policy updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating policy: {str(e)}', 'danger')
    return redirect(url_for('employee_policies', type=policy_type))


@app.route('/employee/policies/delete/<policy_type>/<int:policy_id>', methods=['POST'])
@employee_required
def employee_delete_policy(policy_type, policy_id):
    try:
        if policy_type == 'home':
            execute_query("DELETE FROM RAH_HOME_POLICY WHERE HPOLICY_ID = %s", (policy_id,), commit=True)
        else:
            execute_query("DELETE FROM RAH_AUTO_POLICY WHERE APOLICY_ID = %s", (policy_id,), commit=True)
        clear_cache()
        flash('Policy deleted successfully.', 'success')
    except Exception as e:
        flash(f'Error deleting policy: {str(e)}', 'danger')
    return redirect(url_for('employee_policies', type=policy_type))


@app.route('/employee/policies/renew/<policy_type>/<int:policy_id>', methods=['POST'])
@employee_required
def employee_renew_policy(policy_type, policy_id):
    new_start = request.form.get('new_start')
    new_end = request.form.get('new_end')
    new_premium = float(request.form.get('new_premium'))

    try:
        execute_proc('sp_renew_policy', (policy_type, policy_id, new_start, new_end, new_premium))
        clear_cache()
        flash('Policy renewed successfully!', 'success')
    except Exception as e:
        flash(f'Error renewing policy: {str(e)}', 'danger')
    return redirect(url_for('employee_policies', type=policy_type))


# ---- Employee Invoices ----
@app.route('/employee/invoices', methods=['GET'])
@employee_required
def employee_invoices():
    inv_type = request.args.get('type', 'home')

    if inv_type == 'home':
        invoices = execute_query(
            """SELECT hi.*, hp.CUST_ID, c.FIRST_NAME, c.LAST_NAME,
               COALESCE(SUM(hpay.HPAYMENT_AMT), 0) as paid_amount
               FROM RAH_HOME_INVOICE hi
               JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
               JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID
               LEFT JOIN RAH_HOME_PAYMENT hpay ON hi.HINVOICE_ID = hpay.HINVOICE_ID
               GROUP BY hi.HINVOICE_ID ORDER BY hi.HINVOICE_DT DESC""",
            fetchall=True
        )
        policies = execute_query(
            """SELECT hp.HPOLICY_ID as id, c.FIRST_NAME, c.LAST_NAME
               FROM RAH_HOME_POLICY hp JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID
               WHERE hp.HPOLICY_STATUS = 'C' ORDER BY hp.HPOLICY_ID""",
            fetchall=True
        )
    else:
        invoices = execute_query(
            """SELECT ai.*, ap.CUST_ID, c.FIRST_NAME, c.LAST_NAME,
               COALESCE(SUM(apay.APAYMENT_AMT), 0) as paid_amount
               FROM RAH_AUTO_INVOICE ai
               JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
               JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
               LEFT JOIN RAH_AUTO_PAYMENT apay ON ai.AINVOICE_ID = apay.AINVOICE_ID
               GROUP BY ai.AINVOICE_ID ORDER BY ai.AINVOICE_DT DESC""",
            fetchall=True
        )
        policies = execute_query(
            """SELECT ap.APOLICY_ID as id, c.FIRST_NAME, c.LAST_NAME
               FROM RAH_AUTO_POLICY ap JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
               WHERE ap.APOLICY_STATUS = 'C' ORDER BY ap.APOLICY_ID""",
            fetchall=True
        )

    return render_template('employee/invoices.html', invoices=invoices, inv_type=inv_type, policies=policies)


@app.route('/employee/invoices/add', methods=['POST'])
@employee_required
def employee_add_invoice():
    inv_type = request.form.get('inv_type')
    policy_id = int(request.form.get('policy_id'))
    inv_date = request.form.get('invoice_date')
    due_date = request.form.get('due_date')
    amount = float(request.form.get('amount'))

    try:
        execute_proc('sp_generate_invoice', (inv_type, policy_id, inv_date, due_date, amount))
        clear_cache()
        flash('Invoice generated successfully!', 'success')
    except Exception as e:
        flash(f'Error generating invoice: {str(e)}', 'danger')
    return redirect(url_for('employee_invoices', type=inv_type))


# ---- Employee Payments ----
@app.route('/employee/payments')
@employee_required
def employee_payments():
    payments = execute_query(
        """(SELECT 'Home' as type, hp.HPAYMENT_ID as id, hp.HPAYMENT_DT as pay_date,
            hp.HPAYMENT_AMT as amount, hp.HPAYMENT_METHOD as method,
            hp.HINVOICE_ID as invoice_id, c.FIRST_NAME, c.LAST_NAME
           FROM RAH_HOME_PAYMENT hp
           JOIN RAH_HOME_INVOICE hi ON hp.HINVOICE_ID = hi.HINVOICE_ID
           JOIN RAH_HOME_POLICY hpol ON hi.HPOLICY_ID = hpol.HPOLICY_ID
           JOIN RAH_CUSTOMER c ON hpol.CUST_ID = c.CUST_ID)
           UNION ALL
           (SELECT 'Auto' as type, ap.APAYMENT_ID as id, ap.APAYMENT_DT as pay_date,
            ap.APAYMENT_AMT as amount, ap.APAYMENT_METHOD as method,
            ap.AINVOICE_ID as invoice_id, c.FIRST_NAME, c.LAST_NAME
           FROM RAH_AUTO_PAYMENT ap
           JOIN RAH_AUTO_INVOICE ai ON ap.AINVOICE_ID = ai.AINVOICE_ID
           JOIN RAH_AUTO_POLICY apol ON ai.APOLICY_ID = apol.APOLICY_ID
           JOIN RAH_CUSTOMER c ON apol.CUST_ID = c.CUST_ID)
           ORDER BY pay_date DESC""",
        fetchall=True
    )
    return render_template('employee/payments.html', payments=payments)


# ---- Employee Vehicles ----
@app.route('/employee/vehicles', methods=['GET'])
@employee_required
def employee_vehicles():
    vehicles = execute_query(
        """SELECT v.*, ap.CUST_ID, c.FIRST_NAME, c.LAST_NAME
           FROM RAH_VEHICLE v
           JOIN RAH_AUTO_POLICY ap ON v.APOLICY_ID = ap.APOLICY_ID
           JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
           ORDER BY v.VEHICLE_YEAR DESC""",
        fetchall=True
    )
    policies = execute_query(
        """SELECT ap.APOLICY_ID as id, c.FIRST_NAME, c.LAST_NAME
           FROM RAH_AUTO_POLICY ap JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
           WHERE ap.APOLICY_STATUS = 'C' ORDER BY ap.APOLICY_ID""",
        fetchall=True
    )
    return render_template('employee/vehicles.html', vehicles=vehicles, policies=policies)


@app.route('/employee/vehicles/add', methods=['POST'])
@employee_required
def employee_add_vehicle():
    vin = sanitize(request.form.get('vin', '').strip())
    make = sanitize(request.form.get('make', '').strip())
    model = sanitize(request.form.get('model', '').strip())
    year = int(request.form.get('year'))
    status = request.form.get('status', 'L')
    apolicy_id = int(request.form.get('apolicy_id'))

    try:
        max_id = execute_query("SELECT COALESCE(MAX(VEHICLE_ID),0)+1 AS nid FROM RAH_VEHICLE", fetchone=True)
        execute_query(
            """INSERT INTO RAH_VEHICLE (VEHICLE_ID, VEHICLE_VIN, VEHICLE_MAKE, VEHICLE_MODEL,
               VEHICLE_YEAR, VEHICLE_STATUS, APOLICY_ID) VALUES (%s,%s,%s,%s,%s,%s,%s)""",
            (max_id['nid'], vin, make, model, year, status, apolicy_id), commit=True
        )
        clear_cache()
        flash('Vehicle added successfully!', 'success')
    except Exception as e:
        flash(f'Error adding vehicle: {str(e)}', 'danger')
    return redirect(url_for('employee_vehicles'))


@app.route('/employee/vehicles/edit/<int:vehicle_id>', methods=['POST'])
@employee_required
def employee_edit_vehicle(vehicle_id):
    vin = sanitize(request.form.get('vin', '').strip())
    make = sanitize(request.form.get('make', '').strip())
    model = sanitize(request.form.get('model', '').strip())
    year = int(request.form.get('year'))
    status = request.form.get('status')

    try:
        execute_query(
            """UPDATE RAH_VEHICLE SET VEHICLE_VIN=%s, VEHICLE_MAKE=%s, VEHICLE_MODEL=%s,
               VEHICLE_YEAR=%s, VEHICLE_STATUS=%s WHERE VEHICLE_ID=%s""",
            (vin, make, model, year, status, vehicle_id), commit=True
        )
        clear_cache()
        flash('Vehicle updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating vehicle: {str(e)}', 'danger')
    return redirect(url_for('employee_vehicles'))


@app.route('/employee/vehicles/delete/<int:vehicle_id>', methods=['POST'])
@employee_required
def employee_delete_vehicle(vehicle_id):
    try:
        execute_query("DELETE FROM RAH_VEHICLE WHERE VEHICLE_ID = %s", (vehicle_id,), commit=True)
        clear_cache()
        flash('Vehicle deleted successfully.', 'success')
    except Exception as e:
        flash(f'Error deleting vehicle: {str(e)}', 'danger')
    return redirect(url_for('employee_vehicles'))


# ---- Employee Drivers ----
@app.route('/employee/drivers', methods=['GET'])
@employee_required
def employee_drivers():
    drivers = execute_query(
        """SELECT d.*, GROUP_CONCAT(CONCAT(v.VEHICLE_MAKE, ' ', v.VEHICLE_MODEL) SEPARATOR ', ') as vehicles
           FROM RAH_DRIVER d
           LEFT JOIN RAH_VEHICLE_DRIVER vd ON d.DRIVER_ID = vd.DRIVER_ID
           LEFT JOIN RAH_VEHICLE v ON vd.VEHICLE_ID = v.VEHICLE_ID
           GROUP BY d.DRIVER_ID ORDER BY d.DRIVER_LNAME""",
        fetchall=True
    )
    vehicles = execute_query("SELECT VEHICLE_ID, VEHICLE_MAKE, VEHICLE_MODEL, VEHICLE_YEAR FROM RAH_VEHICLE ORDER BY VEHICLE_MAKE", fetchall=True)
    return render_template('employee/drivers.html', drivers=drivers, vehicles=vehicles)


@app.route('/employee/drivers/add', methods=['POST'])
@employee_required
def employee_add_driver():
    license_no = sanitize(request.form.get('license_no', '').strip())
    fname = sanitize(request.form.get('fname', '').strip())
    lname = sanitize(request.form.get('lname', '').strip())
    age = int(request.form.get('age'))
    vehicle_ids = request.form.getlist('vehicle_ids')

    try:
        max_id = execute_query("SELECT COALESCE(MAX(DRIVER_ID),0)+1 AS nid FROM RAH_DRIVER", fetchone=True)
        new_id = max_id['nid']

        conn = get_db()
        conn.start_transaction()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO RAH_DRIVER (DRIVER_ID, DRIVER_LICENSE_NO, DRIVER_FNAME, DRIVER_LNAME, DRIVER_AGE) VALUES (%s,%s,%s,%s,%s)",
            (new_id, license_no, fname, lname, age)
        )
        for vid in vehicle_ids:
            cursor.execute("INSERT INTO RAH_VEHICLE_DRIVER (VEHICLE_ID, DRIVER_ID) VALUES (%s, %s)", (int(vid), new_id))
        conn.commit()
        cursor.close()
        clear_cache()
        flash('Driver added successfully!', 'success')
    except Exception as e:
        flash(f'Error adding driver: {str(e)}', 'danger')
    return redirect(url_for('employee_drivers'))


@app.route('/employee/drivers/edit/<int:driver_id>', methods=['POST'])
@employee_required
def employee_edit_driver(driver_id):
    license_no = sanitize(request.form.get('license_no', '').strip())
    fname = sanitize(request.form.get('fname', '').strip())
    lname = sanitize(request.form.get('lname', '').strip())
    age = int(request.form.get('age'))

    try:
        execute_query(
            "UPDATE RAH_DRIVER SET DRIVER_LICENSE_NO=%s, DRIVER_FNAME=%s, DRIVER_LNAME=%s, DRIVER_AGE=%s WHERE DRIVER_ID=%s",
            (license_no, fname, lname, age, driver_id), commit=True
        )
        clear_cache()
        flash('Driver updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating driver: {str(e)}', 'danger')
    return redirect(url_for('employee_drivers'))


@app.route('/employee/drivers/delete/<int:driver_id>', methods=['POST'])
@employee_required
def employee_delete_driver(driver_id):
    try:
        execute_query("DELETE FROM RAH_DRIVER WHERE DRIVER_ID = %s", (driver_id,), commit=True)
        clear_cache()
        flash('Driver deleted successfully.', 'success')
    except Exception as e:
        flash(f'Error deleting driver: {str(e)}', 'danger')
    return redirect(url_for('employee_drivers'))


@app.route('/employee/drivers/assign', methods=['POST'])
@employee_required
def employee_assign_driver():
    driver_id = int(request.form.get('driver_id'))
    vehicle_id = int(request.form.get('vehicle_id'))
    try:
        execute_query(
            "INSERT INTO RAH_VEHICLE_DRIVER (VEHICLE_ID, DRIVER_ID) VALUES (%s, %s)",
            (vehicle_id, driver_id), commit=True
        )
        flash('Driver assigned to vehicle!', 'success')
    except Exception as e:
        flash(f'Assignment failed: {str(e)}', 'danger')
    return redirect(url_for('employee_drivers'))


# ---- Employee Reports ----
@app.route('/employee/reports')
@employee_required
def employee_reports():
    return render_template('employee/reports.html')


# ---- Employee Index Analysis ----
@app.route('/employee/index-analysis')
@employee_required
def employee_index_analysis():
    # Get all custom indexes
    indexes = execute_query(
        """SELECT INDEX_NAME, TABLE_NAME, COLUMN_NAME, SEQ_IN_INDEX
           FROM INFORMATION_SCHEMA.STATISTICS
           WHERE TABLE_SCHEMA = 'nice_insurance'
           AND INDEX_NAME LIKE 'idx_%'
           ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX""",
        fetchall=True
    )
    return render_template('employee/index_analysis.html', indexes=indexes)


# ============================================================
# API ROUTES (JSON for Charts)
# ============================================================
@app.route('/api/chart/premium-by-month')
@login_required
def api_premium_by_month():
    data = execute_query(
        """(SELECT DATE_FORMAT(HPOLICY_START_DT, '%b %Y') as month,
               DATE_FORMAT(HPOLICY_START_DT, '%Y-%m') as month_key,
               SUM(HPREMIUM_AMT) as total, 'Home' as type
           FROM RAH_HOME_POLICY WHERE HPOLICY_START_DT IS NOT NULL GROUP BY month_key, month)
           UNION ALL
           (SELECT DATE_FORMAT(APOLICY_START_DT, '%b %Y') as month,
               DATE_FORMAT(APOLICY_START_DT, '%Y-%m') as month_key,
               SUM(APREMIUM_AMT) as total, 'Auto' as type
           FROM RAH_AUTO_POLICY WHERE APOLICY_START_DT IS NOT NULL GROUP BY month_key, month)
           ORDER BY month_key""",
        fetchall=True
    )
    return jsonify([{k: float(v) if isinstance(v, Decimal) else v for k, v in row.items()} for row in data])


@app.route('/api/chart/policy-distribution')
@login_required
def api_policy_distribution():
    home_active = execute_query("SELECT COUNT(*) as cnt FROM RAH_HOME_POLICY WHERE HPOLICY_STATUS='C'", fetchone=True)
    home_expired = execute_query("SELECT COUNT(*) as cnt FROM RAH_HOME_POLICY WHERE HPOLICY_STATUS='E'", fetchone=True)
    auto_active = execute_query("SELECT COUNT(*) as cnt FROM RAH_AUTO_POLICY WHERE APOLICY_STATUS='C'", fetchone=True)
    auto_expired = execute_query("SELECT COUNT(*) as cnt FROM RAH_AUTO_POLICY WHERE APOLICY_STATUS='E'", fetchone=True)
    return jsonify({
        'labels': ['Home Active', 'Home Expired', 'Auto Active', 'Auto Expired'],
        'data': [home_active['cnt'], home_expired['cnt'], auto_active['cnt'], auto_expired['cnt']]
    })


@app.route('/api/chart/customer-by-state')
@login_required
def api_customer_by_state():
    data = execute_query(
        "SELECT STATE, COUNT(*) as cnt FROM RAH_CUSTOMER GROUP BY STATE ORDER BY cnt DESC",
        fetchall=True
    )
    return jsonify({'labels': [r['STATE'] for r in data], 'data': [r['cnt'] for r in data]})


@app.route('/api/chart/payment-methods')
@login_required
def api_payment_methods():
    data = execute_query(
        """SELECT method, SUM(total) as cnt FROM (
           (SELECT HPAYMENT_METHOD as method, COUNT(*) as total FROM RAH_HOME_PAYMENT GROUP BY HPAYMENT_METHOD)
           UNION ALL
           (SELECT APAYMENT_METHOD as method, COUNT(*) as total FROM RAH_AUTO_PAYMENT GROUP BY APAYMENT_METHOD)
           ) combined GROUP BY method ORDER BY cnt DESC""",
        fetchall=True
    )
    return jsonify({'labels': [r['method'] for r in data], 'data': [int(r['cnt']) for r in data]})


@app.route('/api/chart/top-customers')
@login_required
def api_top_customers():
    data = execute_query(
        """SELECT c.FIRST_NAME, c.LAST_NAME, fn_total_premium(c.CUST_ID) as total_premium
           FROM RAH_CUSTOMER c
           HAVING total_premium > 0
           ORDER BY total_premium DESC LIMIT 10""",
        fetchall=True
    )
    return jsonify({
        'labels': [f"{r['FIRST_NAME']} {r['LAST_NAME']}" for r in data],
        'data': [float(r['total_premium']) for r in data]
    })


@app.route('/api/chart/monthly-revenue')
@login_required
def api_monthly_revenue():
    data = execute_query(
        """SELECT
               month_key,
               DATE_FORMAT(STR_TO_DATE(CONCAT(month_key, '-01'), '%Y-%m-%d'), '%b %Y') AS label,
               total
           FROM (
               SELECT month_key, SUM(amount) AS total FROM (
                   SELECT DATE_FORMAT(HPAYMENT_DT, '%Y-%m') AS month_key, HPAYMENT_AMT AS amount
                   FROM RAH_HOME_PAYMENT WHERE HPAYMENT_DT IS NOT NULL
                   UNION ALL
                   SELECT DATE_FORMAT(APAYMENT_DT, '%Y-%m') AS month_key, APAYMENT_AMT AS amount
                   FROM RAH_AUTO_PAYMENT WHERE APAYMENT_DT IS NOT NULL
               ) combined
               WHERE month_key IS NOT NULL
               GROUP BY month_key
           ) grouped
           ORDER BY month_key""",
        fetchall=True
    )
    return jsonify({
        'labels': [r['label'] for r in data],
        'data': [float(r['total']) for r in data]
    })


@app.route('/api/chart/invoice-status')
@login_required
def api_invoice_status():
    home_total = execute_query("SELECT COUNT(*) as cnt FROM RAH_HOME_INVOICE", fetchone=True)
    auto_total = execute_query("SELECT COUNT(*) as cnt FROM RAH_AUTO_INVOICE", fetchone=True)
    home_paid = execute_query(
        """SELECT COUNT(DISTINCT hi.HINVOICE_ID) as cnt
           FROM RAH_HOME_INVOICE hi
           JOIN RAH_HOME_PAYMENT hp ON hi.HINVOICE_ID = hp.HINVOICE_ID
           WHERE hp.HPAYMENT_AMT >= hi.HINVOICE_AMT""",
        fetchone=True
    )
    auto_paid = execute_query(
        """SELECT COUNT(DISTINCT ai.AINVOICE_ID) as cnt
           FROM RAH_AUTO_INVOICE ai
           JOIN RAH_AUTO_PAYMENT ap ON ai.AINVOICE_ID = ap.AINVOICE_ID
           WHERE ap.APAYMENT_AMT >= ai.AINVOICE_AMT""",
        fetchone=True
    )
    return jsonify({
        'labels': ['Home Paid', 'Home Unpaid', 'Auto Paid', 'Auto Unpaid'],
        'data': [
            home_paid['cnt'],
            home_total['cnt'] - home_paid['cnt'],
            auto_paid['cnt'],
            auto_total['cnt'] - auto_paid['cnt']
        ]
    })


@app.route('/api/chart/customer-payments')
@customer_required
def api_customer_payments():
    cust_id = session['cust_id']
    data = execute_query(
        """SELECT month, SUM(amount) as total FROM (
           (SELECT DATE_FORMAT(hp.HPAYMENT_DT, '%Y-%m') as month, hp.HPAYMENT_AMT as amount
            FROM RAH_HOME_PAYMENT hp
            JOIN RAH_HOME_INVOICE hi ON hp.HINVOICE_ID = hi.HINVOICE_ID
            JOIN RAH_HOME_POLICY hpol ON hi.HPOLICY_ID = hpol.HPOLICY_ID
            WHERE hpol.CUST_ID = %s)
           UNION ALL
           (SELECT DATE_FORMAT(ap.APAYMENT_DT, '%Y-%m') as month, ap.APAYMENT_AMT as amount
            FROM RAH_AUTO_PAYMENT ap
            JOIN RAH_AUTO_INVOICE ai ON ap.AINVOICE_ID = ai.AINVOICE_ID
            JOIN RAH_AUTO_POLICY apol ON ai.APOLICY_ID = apol.APOLICY_ID
            WHERE apol.CUST_ID = %s)
           ) combined GROUP BY month ORDER BY month""",
        (cust_id, cust_id), fetchall=True
    )
    return jsonify({
        'labels': [r['month'] for r in data],
        'data': [float(r['total']) for r in data]
    })


@app.route('/api/chart/customer-premium-dist')
@customer_required
def api_customer_premium_dist():
    cust_id = session['cust_id']
    home_total = execute_query(
        "SELECT COALESCE(SUM(HPREMIUM_AMT), 0) as total FROM RAH_HOME_POLICY WHERE CUST_ID=%s AND HPOLICY_STATUS='C'",
        (cust_id,), fetchone=True
    )
    auto_total = execute_query(
        "SELECT COALESCE(SUM(APREMIUM_AMT), 0) as total FROM RAH_AUTO_POLICY WHERE CUST_ID=%s AND APOLICY_STATUS='C'",
        (cust_id,), fetchone=True
    )
    return jsonify({
        'labels': ['Home Premium', 'Auto Premium'],
        'data': [float(home_total['total']), float(auto_total['total'])]
    })


@app.route('/api/table-counts')
@login_required
def api_table_counts():
    # Table names are hardcoded (not from user input) - safe to interpolate
    ALLOWED_TABLES = {
        'RAH_CUSTOMER', 'RAH_HOME_POLICY', 'RAH_AUTO_POLICY', 'RAH_HOME_INVOICE',
        'RAH_AUTO_INVOICE', 'RAH_HOME_PAYMENT', 'RAH_AUTO_PAYMENT', 'RAH_VEHICLE',
        'RAH_DRIVER', 'RAH_HOME', 'RAH_VEHICLE_DRIVER', 'RAH_CUST_TYPE',
        'RAH_USER', 'RAH_LOGIN_HISTORY', 'RAH_POLICY_AUDIT', 'RAH_PASSWORD_RESET'
    }
    counts = {}
    for t in ALLOWED_TABLES:
        # Table name from hardcoded whitelist, not user input
        row = execute_query("SELECT COUNT(*) as cnt FROM " + t, fetchone=True)
        counts[t] = row['cnt']
    return jsonify(counts)


@app.route('/api/index-analysis')
@employee_required
def api_index_analysis():
    """Show EXPLAIN analysis for queries with and without indexes."""
    analyses = []

    test_queries = [
        {
            'name': 'Customer lookup by state',
            'query': "EXPLAIN SELECT * FROM RAH_CUSTOMER WHERE STATE = 'NY'",
            'index': 'idx_customer_state',
            'table': 'RAH_CUSTOMER',
            'columns': 'STATE',
            'reason': 'Frequent filtering by state for geographic analytics and reports'
        },
        {
            'name': 'Home policies by customer',
            'query': "EXPLAIN SELECT * FROM RAH_HOME_POLICY WHERE CUST_ID = 1",
            'index': 'idx_home_policy_cust',
            'table': 'RAH_HOME_POLICY',
            'columns': 'CUST_ID',
            'reason': 'Join optimization when loading customer policies'
        },
        {
            'name': 'Active home policies',
            'query': "EXPLAIN SELECT * FROM RAH_HOME_POLICY WHERE HPOLICY_STATUS = 'C'",
            'index': 'idx_home_policy_status',
            'table': 'RAH_HOME_POLICY',
            'columns': 'HPOLICY_STATUS',
            'reason': 'Status filtering for active vs expired policy dashboards'
        },
        {
            'name': 'Auto policies by customer',
            'query': "EXPLAIN SELECT * FROM RAH_AUTO_POLICY WHERE CUST_ID = 1",
            'index': 'idx_auto_policy_cust',
            'table': 'RAH_AUTO_POLICY',
            'columns': 'CUST_ID',
            'reason': 'Join optimization when loading customer auto policies'
        },
        {
            'name': 'Home invoices by policy',
            'query': "EXPLAIN SELECT * FROM RAH_HOME_INVOICE WHERE HPOLICY_ID = 1",
            'index': 'idx_home_invoice_policy',
            'table': 'RAH_HOME_INVOICE',
            'columns': 'HPOLICY_ID',
            'reason': 'Join optimization linking invoices to home policies'
        },
        {
            'name': 'Vehicles by auto policy',
            'query': "EXPLAIN SELECT * FROM RAH_VEHICLE WHERE APOLICY_ID = 1",
            'index': 'idx_vehicle_policy',
            'table': 'RAH_VEHICLE',
            'columns': 'APOLICY_ID',
            'reason': 'Finding all vehicles under a specific auto policy'
        },
        {
            'name': 'Users by role',
            'query': "EXPLAIN SELECT * FROM RAH_USER WHERE ROLE = 'customer'",
            'index': 'idx_user_role',
            'table': 'RAH_USER',
            'columns': 'ROLE',
            'reason': 'Role-based query optimization for authentication and access control'
        },
        {
            'name': 'Customer lookup by city',
            'query': "EXPLAIN SELECT * FROM RAH_CUSTOMER WHERE CITY = 'Brooklyn'",
            'index': 'idx_customer_city',
            'table': 'RAH_CUSTOMER',
            'columns': 'CITY',
            'reason': 'Frequent filtering by city for geographic analytics'
        },
    ]

    for tq in test_queries:
        try:
            result = execute_query(tq['query'], fetchall=True)
            analyses.append({
                'name': tq['name'],
                'index': tq['index'],
                'table': tq['table'],
                'columns': tq['columns'],
                'reason': tq['reason'],
                'explain': result
            })
        except Exception as e:
            analyses.append({
                'name': tq['name'],
                'index': tq['index'],
                'table': tq['table'],
                'columns': tq['columns'],
                'reason': tq['reason'],
                'explain': [{'error': str(e)}]
            })

    return jsonify(analyses)


# ============================================================
# Error Handlers
# ============================================================
@app.errorhandler(404)
def not_found(e):
    return render_template('base.html', error_code=404, error_message='Page not found'), 404


@app.errorhandler(500)
def server_error(e):
    return render_template('base.html', error_code=500, error_message='Internal server error'), 500


# ============================================================
# Run
# ============================================================
if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(debug=True, host='0.0.0.0', port=port)
