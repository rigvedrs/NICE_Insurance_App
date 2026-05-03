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
        execute_proc('sp_record_login_success', (user['USER_ID'], request.remote_addr))

        session.permanent = True
        session['user_id'] = user['USER_ID']
        session['username'] = user['USERNAME']
        session['role'] = user['ROLE']
        session['cust_id'] = user['CUST_ID']
        session['last_activity'] = datetime.now().isoformat()

        if user['CUST_ID']:
            cust = execute_query(
                "SELECT FIRST_NAME, LAST_NAME FROM vw_customer_directory WHERE customer_ref = %s",
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
        execute_proc('sp_record_login_failure', (user['USER_ID'], request.remote_addr))
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
        cust_type = request.form.get('cust_type', 'H').strip()
        gender = request.form.get('gender', '').strip() or None
        marital_status = request.form.get('marital_status', 'S').strip()

        if not first_name or not last_name or not addr_line1 or not city or not state or not zipcode:
            flash('All required customer fields must be filled.', 'danger')
            return render_template('register.html')
        if cust_type not in ('H', 'A'):
            flash('Customer type must be Home or Auto.', 'danger')
            return render_template('register.html')

        try:
            execute_proc(
                'sp_register_customer',
                (
                    username, password_hash, email, security_question, answer_hash,
                    cust_type, first_name, middle_name, last_name, addr_line1, addr_line2,
                    city, state, zipcode, gender, marital_status
                )
            )
        except mysql.connector.Error as e:
            flash(f'Registration failed: {str(e)}', 'danger')
            return render_template('register.html')
    else:
        execute_proc('sp_register_employee', (username, password_hash, email, security_question, answer_hash))

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
        token = str(uuid.uuid4())
        execute_proc('sp_reset_password', (user['USER_ID'], new_hash, token))
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

    dashboard = execute_query(
        "SELECT * FROM vw_customer_dashboard WHERE customer_ref = %s",
        (cust_id,), fetchone=True
    ) or {}

    # Recent invoices
    recent_invoices = execute_query(
        """(SELECT 'Home' as type, invoice_ref as id, invoice_dt as inv_date,
            due_dt as due_date, amount_due as amount, policy_ref as policy_id
           FROM vw_home_invoices
           WHERE customer_ref = %s)
           UNION ALL
           (SELECT 'Auto' as type, invoice_ref as id, invoice_dt as inv_date,
            due_dt as due_date, amount_due as amount, policy_ref as policy_id
           FROM vw_auto_invoices
           WHERE customer_ref = %s)
           ORDER BY inv_date DESC LIMIT 10""",
        (cust_id, cust_id), fetchall=True
    )

    stats = {
        'active_policies': dashboard.get('active_policies') or 0,
        'total_premium': float(dashboard.get('total_premium') or 0),
        'outstanding_balance': float(dashboard.get('outstanding_balance') or 0),
        'total_paid': float(dashboard.get('total_paid') or 0),
    }

    return render_template('customer/dashboard.html', stats=stats, recent_invoices=recent_invoices)


@app.route('/customer/policies')
@customer_required
def customer_policies():
    cust_id = session['cust_id']

    home_policies = execute_query(
        """SELECT policy_ref AS HPOLICY_ID, start_dt AS HPOLICY_START_DT, end_dt AS HPOLICY_END_DT,
           premium AS HPREMIUM_AMT, status_code AS HPOLICY_STATUS, customer_ref AS CUST_ID,
           HOME_TYPE, HOME_PURCHASE_VAL, HOME_AREA_SQFT, AUTO_FIRE_NOTIF, HOME_SECURITY_SYS,
           SWIMMING_POOL, BASEMENT
           FROM vw_home_policies
           WHERE customer_ref = %s ORDER BY start_dt DESC""",
        (cust_id,), fetchall=True
    )

    auto_policies = execute_query(
        """SELECT policy_ref AS APOLICY_ID, start_dt AS APOLICY_START_DT, end_dt AS APOLICY_END_DT,
           premium AS APREMIUM_AMT, status_code AS APOLICY_STATUS, customer_ref AS CUST_ID,
           vehicle_count
           FROM vw_auto_policies
           WHERE customer_ref = %s
           ORDER BY start_dt DESC""",
        (cust_id,), fetchall=True
    )

    return render_template('customer/policies.html', home_policies=home_policies, auto_policies=auto_policies)


@app.route('/customer/invoices')
@customer_required
def customer_invoices():
    cust_id = session['cust_id']

    home_invoices = execute_query(
        """SELECT invoice_ref AS HINVOICE_ID, policy_ref AS HPOLICY_ID,
           invoice_dt AS HINVOICE_DT, due_dt AS HINVOICE_DUE_DT,
           amount_due AS HINVOICE_AMT, status_code AS HPOLICY_STATUS, paid_amount
           FROM vw_home_invoices
           WHERE customer_ref = %s
           ORDER BY invoice_dt DESC""",
        (cust_id,), fetchall=True
    )

    auto_invoices = execute_query(
        """SELECT invoice_ref AS AINVOICE_ID, policy_ref AS APOLICY_ID,
           invoice_dt AS AINVOICE_DT, due_dt AS AINVOICE_DUE_DT,
           amount_due AS AINVOICE_AMT, status_code AS APOLICY_STATUS, paid_amount
           FROM vw_auto_invoices
           WHERE customer_ref = %s
           ORDER BY invoice_dt DESC""",
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
        """SELECT invoice_ref as invoice_id, 'home' as type, amount_due as amount,
           due_dt as due_date, policy_ref as policy_id,
           amount_due - paid_amount as remaining
           FROM vw_home_invoices
           WHERE customer_ref = %s
           HAVING remaining > 0
           ORDER BY due_dt""",
        (cust_id,), fetchall=True
    )

    auto_invoices = execute_query(
        """SELECT invoice_ref as invoice_id, 'auto' as type, amount_due as amount,
           due_dt as due_date, policy_ref as policy_id,
           amount_due - paid_amount as remaining
           FROM vw_auto_invoices
           WHERE customer_ref = %s
           HAVING remaining > 0
           ORDER BY due_dt""",
        (cust_id,), fetchall=True
    )

    # Payment history
    payments = execute_query(
        """SELECT kind as type, payment_ref as id, pay_date, amount, method, invoice_ref as invoice_id
           FROM vw_all_payments
           WHERE customer_ref = %s
           ORDER BY pay_date DESC""",
        (cust_id,), fetchall=True
    )

    unpaid = list(home_invoices or []) + list(auto_invoices or [])
    return render_template('customer/payments.html', unpaid_invoices=unpaid, payments=payments)


@app.route('/customer/vehicles')
@customer_required
def customer_vehicles():
    cust_id = session['cust_id']
    vehicles = execute_query(
        """SELECT vehicle_ref AS VEHICLE_ID, VEHICLE_VIN, VEHICLE_MAKE, VEHICLE_MODEL,
           VEHICLE_YEAR, VEHICLE_STATUS, policy_ref AS APOLICY_ID, status_code AS APOLICY_STATUS,
           drivers
           FROM vw_customer_vehicles
           WHERE customer_ref = %s ORDER BY VEHICLE_YEAR DESC""",
        (cust_id,), fetchall=True
    )

    vehicle_drivers = {}
    for v in vehicles:
        if v.get('drivers'):
            vehicle_drivers[v['VEHICLE_ID']] = [{'driver_label': d} for d in v['drivers'].split('; ')]
        else:
            vehicle_drivers[v['VEHICLE_ID']] = []

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
            execute_proc('sp_change_address', (cust_id, addr_line1, addr_line2, city, state, zipcode))
            flash('Profile updated successfully!', 'success')
        except Exception as e:
            flash(f'Update failed: {str(e)}', 'danger')
        return redirect(url_for('customer_profile'))

    customer = execute_query(
        """SELECT customer_ref AS CUST_ID, customer_kind AS CUST_TYPE,
           FIRST_NAME, MIDDLE_NAME, LAST_NAME, ADDR_LINE1, ADDR_LINE2,
           CITY, STATE, ZIP, GENDER, MARITAL_STATUS
           FROM vw_customer_directory WHERE customer_ref = %s""",
        (cust_id,), fetchone=True
    )
    user = execute_query(
        "SELECT USERNAME, EMAIL, CREATED_AT, LAST_LOGIN FROM RAH_USER WHERE CUST_ID = %s",
        (cust_id,), fetchone=True
    )
    cust_types = [{'CUST_TYPE': customer['CUST_TYPE']}] if customer else []

    return render_template('customer/profile.html', customer=customer, user=user, cust_types=cust_types)


# ============================================================
# EMPLOYEE ROUTES
# ============================================================
@app.route('/employee/dashboard')
@employee_required
def employee_dashboard():
    total_customers = execute_query("SELECT COUNT(*) as cnt FROM vw_customer_directory", fetchone=True)
    active_home = execute_query("SELECT COUNT(*) as cnt FROM vw_home_policies WHERE status_code = 'C'", fetchone=True)
    active_auto = execute_query("SELECT COUNT(*) as cnt FROM vw_auto_policies WHERE status_code = 'C'", fetchone=True)

    total_revenue = execute_query("SELECT COALESCE(SUM(amount), 0) as total FROM vw_all_payments", fetchone=True)
    outstanding_home = execute_query("SELECT COALESCE(SUM(amount_due - paid_amount), 0) as total FROM vw_home_invoices", fetchone=True)
    outstanding_auto = execute_query("SELECT COALESCE(SUM(amount_due - paid_amount), 0) as total FROM vw_auto_invoices", fetchone=True)

    # Recent audit entries
    recent_audit = execute_query(
        """SELECT audit_ref AS AUDIT_ID, entity AS TABLE_NAME, ref AS RECORD_ID,
           action AS ACTION, actor AS CHANGED_BY, changed_at AS CHANGED_AT
           FROM vw_audit_trail ORDER BY changed_at DESC LIMIT 10""",
        fetchall=True
    )

    stats = {
        'total_customers': total_customers['cnt'],
        'active_policies': (active_home['cnt'] or 0) + (active_auto['cnt'] or 0),
        'total_revenue': float(total_revenue['total'] or 0),
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
            """SELECT customer_ref AS CUST_ID, customer_kind AS CUST_TYPE,
               FIRST_NAME, MIDDLE_NAME, LAST_NAME, ADDR_LINE1, ADDR_LINE2,
               CITY, STATE, ZIP, GENDER, MARITAL_STATUS, customer_kind AS types
               FROM vw_customer_directory
               WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s OR CITY LIKE %s OR STATE LIKE %s
               ORDER BY customer_ref LIMIT %s OFFSET %s""",
            (search_param, search_param, search_param, search_param, per_page, offset), fetchall=True
        )
        total = execute_query(
            """SELECT COUNT(*) as cnt FROM vw_customer_directory
               WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s OR CITY LIKE %s OR STATE LIKE %s""",
            (search_param, search_param, search_param, search_param), fetchone=True
        )
    else:
        customers = execute_query(
            """SELECT customer_ref AS CUST_ID, customer_kind AS CUST_TYPE,
               FIRST_NAME, MIDDLE_NAME, LAST_NAME, ADDR_LINE1, ADDR_LINE2,
               CITY, STATE, ZIP, GENDER, MARITAL_STATUS, customer_kind AS types
               FROM vw_customer_directory
               ORDER BY customer_ref LIMIT %s OFFSET %s""",
            (per_page, offset), fetchall=True
        )
        total = execute_query("SELECT COUNT(*) as cnt FROM vw_customer_directory", fetchone=True)

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
    cust_type = request.form.get('cust_type', 'H')
    gender = request.form.get('gender') or None
    marital_status = request.form.get('marital_status', 'S')

    try:
        result = execute_proc(
            'sp_add_customer',
            (
                cust_type, first_name, middle_name, last_name, addr_line1, addr_line2,
                city, state, zipcode, gender, marital_status
            )
        )
        new_id = result[0][0]['new_cust_id'] if result and result[0] else 'new'
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
    cust_type = request.form.get('cust_type', 'H')
    gender = request.form.get('gender') or None
    marital_status = request.form.get('marital_status', 'S')

    try:
        execute_proc(
            'sp_update_customer',
            (
                cust_id, cust_type, first_name, middle_name, last_name, addr_line1,
                addr_line2, city, state, zipcode, gender, marital_status
            )
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
        execute_proc('sp_delete_customer', (cust_id,))
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
                """SELECT policy_ref AS HPOLICY_ID, customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME,
                   start_dt AS HPOLICY_START_DT, end_dt AS HPOLICY_END_DT,
                   premium AS HPREMIUM_AMT, status_code AS HPOLICY_STATUS,
                   HOME_TYPE, HOME_PURCHASE_VAL
                   FROM vw_home_policies
                   WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s OR CAST(policy_ref AS CHAR) LIKE %s
                   ORDER BY start_dt DESC""",
                (sp, sp, sp), fetchall=True
            )
        else:
            policies = execute_query(
                """SELECT policy_ref AS HPOLICY_ID, customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME,
                   start_dt AS HPOLICY_START_DT, end_dt AS HPOLICY_END_DT,
                   premium AS HPREMIUM_AMT, status_code AS HPOLICY_STATUS,
                   HOME_TYPE, HOME_PURCHASE_VAL
                   FROM vw_home_policies
                   ORDER BY start_dt DESC""", fetchall=True
            )
    else:
        if search:
            sp = f"%{search}%"
            policies = execute_query(
                """SELECT policy_ref AS APOLICY_ID, customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME,
                   start_dt AS APOLICY_START_DT, end_dt AS APOLICY_END_DT,
                   premium AS APREMIUM_AMT, status_code AS APOLICY_STATUS, vehicle_count
                   FROM vw_auto_policies
                   WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s OR CAST(policy_ref AS CHAR) LIKE %s
                   ORDER BY start_dt DESC""",
                (sp, sp, sp), fetchall=True
            )
        else:
            policies = execute_query(
                """SELECT policy_ref AS APOLICY_ID, customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME,
                   start_dt AS APOLICY_START_DT, end_dt AS APOLICY_END_DT,
                   premium AS APREMIUM_AMT, status_code AS APOLICY_STATUS, vehicle_count
                   FROM vw_auto_policies
                   ORDER BY start_dt DESC""",
                fetchall=True
            )

    customers = execute_query(
        """SELECT customer_ref AS CUST_ID, customer_kind AS CUST_TYPE, FIRST_NAME, LAST_NAME
           FROM vw_customer_directory ORDER BY LAST_NAME""",
        fetchall=True
    )
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
            home_type = request.form.get('home_type', 'S')
            if home_type not in ('S', 'M', 'C', 'T'):
                home_type = 'S'
            execute_proc('sp_add_home_policy', (cust_id, start_dt, end_dt, premium, status, home_type))
        else:
            execute_proc('sp_add_auto_policy', (cust_id, start_dt, end_dt, premium, status))

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
            home_type = request.form.get('home_type', 'S')
            if home_type not in ('S', 'M', 'C', 'T'):
                home_type = 'S'
            execute_proc('sp_update_home_policy', (policy_id, start_dt, end_dt, premium, status, home_type))
        else:
            execute_proc('sp_update_auto_policy', (policy_id, start_dt, end_dt, premium, status))
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
            execute_proc('sp_delete_home_policy', (policy_id,))
        else:
            execute_proc('sp_delete_auto_policy', (policy_id,))
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
    search = request.args.get('search', '').strip()
    sp = f"%{search}%" if search else None

    if inv_type == 'home':
        if search:
            invoices = execute_query(
                """SELECT invoice_ref AS HINVOICE_ID, policy_ref AS HPOLICY_ID,
                   customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME, invoice_dt AS HINVOICE_DT,
                   due_dt AS HINVOICE_DUE_DT, amount_due AS HINVOICE_AMT, paid_amount
                   FROM vw_home_invoices
                   WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s
                   OR CAST(invoice_ref AS CHAR) LIKE %s OR CAST(policy_ref AS CHAR) LIKE %s
                   ORDER BY invoice_dt DESC""",
                (sp, sp, sp, sp), fetchall=True
            )
        else:
            invoices = execute_query(
                """SELECT invoice_ref AS HINVOICE_ID, policy_ref AS HPOLICY_ID,
                   customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME, invoice_dt AS HINVOICE_DT,
                   due_dt AS HINVOICE_DUE_DT, amount_due AS HINVOICE_AMT, paid_amount
                   FROM vw_home_invoices
                   ORDER BY invoice_dt DESC""",
                fetchall=True
            )
        policies = execute_query(
            """SELECT policy_ref as id, FIRST_NAME, LAST_NAME
               FROM vw_home_policies
               WHERE status_code = 'C' ORDER BY policy_ref""",
            fetchall=True
        )
    else:
        if search:
            invoices = execute_query(
                """SELECT invoice_ref AS AINVOICE_ID, policy_ref AS APOLICY_ID,
                   customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME, invoice_dt AS AINVOICE_DT,
                   due_dt AS AINVOICE_DUE_DT, amount_due AS AINVOICE_AMT, paid_amount
                   FROM vw_auto_invoices
                   WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s
                   OR CAST(invoice_ref AS CHAR) LIKE %s OR CAST(policy_ref AS CHAR) LIKE %s
                   ORDER BY invoice_dt DESC""",
                (sp, sp, sp, sp), fetchall=True
            )
        else:
            invoices = execute_query(
                """SELECT invoice_ref AS AINVOICE_ID, policy_ref AS APOLICY_ID,
                   customer_ref AS CUST_ID, FIRST_NAME, LAST_NAME, invoice_dt AS AINVOICE_DT,
                   due_dt AS AINVOICE_DUE_DT, amount_due AS AINVOICE_AMT, paid_amount
                   FROM vw_auto_invoices
                   ORDER BY invoice_dt DESC""",
                fetchall=True
            )
        policies = execute_query(
            """SELECT policy_ref as id, FIRST_NAME, LAST_NAME
               FROM vw_auto_policies
               WHERE status_code = 'C' ORDER BY policy_ref""",
            fetchall=True
        )

    return render_template(
        'employee/invoices.html', invoices=invoices, inv_type=inv_type, policies=policies, search=search
    )


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
    search = request.args.get('search', '').strip()
    sp = f"%{search}%"
    if search:
        payments = execute_query(
            """SELECT kind as type, payment_ref as id, pay_date, amount, method,
               invoice_ref as invoice_id, FIRST_NAME, LAST_NAME
               FROM vw_all_payments
               WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s
               OR CAST(payment_ref AS CHAR) LIKE %s OR CAST(invoice_ref AS CHAR) LIKE %s
               OR method LIKE %s OR CAST(amount AS CHAR) LIKE %s OR kind LIKE %s
               ORDER BY pay_date DESC""",
            (sp, sp, sp, sp, sp, sp, sp),
            fetchall=True,
        )
    else:
        payments = execute_query(
            """SELECT kind as type, payment_ref as id, pay_date, amount, method,
               invoice_ref as invoice_id, FIRST_NAME, LAST_NAME
               FROM vw_all_payments
               ORDER BY pay_date DESC""",
            fetchall=True,
        )
    return render_template('employee/payments.html', payments=payments, search=search)


# ---- Employee Vehicles ----
@app.route('/employee/vehicles', methods=['GET'])
@employee_required
def employee_vehicles():
    search = request.args.get('search', '').strip()
    sp = f"%{search}%"
    if search:
        vehicles = execute_query(
            """SELECT vehicle_ref AS VEHICLE_ID, VEHICLE_VIN, VEHICLE_MAKE, VEHICLE_MODEL,
               VEHICLE_YEAR, VEHICLE_STATUS, policy_ref AS APOLICY_ID, customer_ref AS CUST_ID,
               FIRST_NAME, LAST_NAME, driver_count
               FROM vw_employee_vehicles
               WHERE FIRST_NAME LIKE %s OR LAST_NAME LIKE %s
               OR VEHICLE_VIN LIKE %s OR VEHICLE_MAKE LIKE %s OR VEHICLE_MODEL LIKE %s
               OR CAST(VEHICLE_YEAR AS CHAR) LIKE %s OR CAST(vehicle_ref AS CHAR) LIKE %s
               OR CAST(policy_ref AS CHAR) LIKE %s
               ORDER BY VEHICLE_YEAR DESC""",
            (sp, sp, sp, sp, sp, sp, sp, sp),
            fetchall=True,
        )
    else:
        vehicles = execute_query(
            """SELECT vehicle_ref AS VEHICLE_ID, VEHICLE_VIN, VEHICLE_MAKE, VEHICLE_MODEL,
               VEHICLE_YEAR, VEHICLE_STATUS, policy_ref AS APOLICY_ID, customer_ref AS CUST_ID,
               FIRST_NAME, LAST_NAME, driver_count
               FROM vw_employee_vehicles
               ORDER BY VEHICLE_YEAR DESC""",
            fetchall=True,
        )
    policies = execute_query(
        """SELECT policy_ref as id, FIRST_NAME, LAST_NAME
           FROM vw_auto_policies
           WHERE status_code = 'C' ORDER BY policy_ref""",
        fetchall=True
    )
    return render_template('employee/vehicles.html', vehicles=vehicles, policies=policies, search=search)


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
        execute_proc('sp_add_vehicle', (vin, make, model, year, status, apolicy_id))
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
        execute_proc('sp_update_vehicle', (vehicle_id, vin, make, model, year, status))
        clear_cache()
        flash('Vehicle updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating vehicle: {str(e)}', 'danger')
    return redirect(url_for('employee_vehicles'))


@app.route('/employee/vehicles/delete/<int:vehicle_id>', methods=['POST'])
@employee_required
def employee_delete_vehicle(vehicle_id):
    try:
        execute_proc('sp_delete_vehicle', (vehicle_id,))
        clear_cache()
        flash('Vehicle deleted successfully.', 'success')
    except Exception as e:
        flash(f'Error deleting vehicle: {str(e)}', 'danger')
    return redirect(url_for('employee_vehicles'))


# ---- Employee Drivers ----
@app.route('/employee/drivers', methods=['GET'])
@employee_required
def employee_drivers():
    search = request.args.get('search', '').strip()
    sp = f"%{search}%"
    if search:
        drivers = execute_query(
            """SELECT driver_ref AS DRIVER_ID, DRIVER_LICENSE_NO, DRIVER_FNAME, DRIVER_LNAME,
               DRIVER_AGE, vehicle_ref AS VEHICLE_ID, vehicle_label as vehicles, VEHICLE_VIN
               FROM vw_employee_drivers
               WHERE DRIVER_LICENSE_NO LIKE %s OR DRIVER_FNAME LIKE %s OR DRIVER_LNAME LIKE %s
               OR CAST(driver_ref AS CHAR) LIKE %s OR CAST(DRIVER_AGE AS CHAR) LIKE %s
               OR VEHICLE_VIN LIKE %s OR vehicle_label LIKE %s OR CAST(vehicle_ref AS CHAR) LIKE %s
               OR vehicle_label LIKE %s
               ORDER BY DRIVER_LNAME""",
            (sp, sp, sp, sp, sp, sp, sp, sp, sp),
            fetchall=True,
        )
    else:
        drivers = execute_query(
            """SELECT driver_ref AS DRIVER_ID, DRIVER_LICENSE_NO, DRIVER_FNAME, DRIVER_LNAME,
               DRIVER_AGE, vehicle_ref AS VEHICLE_ID, vehicle_label as vehicles, VEHICLE_VIN
               FROM vw_employee_drivers
               ORDER BY DRIVER_LNAME""",
            fetchall=True,
        )
    vehicles = execute_query(
        """SELECT vehicle_ref AS VEHICLE_ID, VEHICLE_MAKE, VEHICLE_MODEL, VEHICLE_YEAR
           FROM vw_employee_vehicles ORDER BY VEHICLE_MAKE""",
        fetchall=True
    )
    return render_template('employee/drivers.html', drivers=drivers, vehicles=vehicles, search=search)


@app.route('/employee/drivers/add', methods=['POST'])
@employee_required
def employee_add_driver():
    license_no = sanitize(request.form.get('license_no', '').strip())
    fname = sanitize(request.form.get('fname', '').strip())
    lname = sanitize(request.form.get('lname', '').strip())
    age = int(request.form.get('age'))
    vehicle_id = int(request.form.get('vehicle_id'))

    try:
        execute_proc('sp_add_driver', (license_no, fname, lname, age, vehicle_id))
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
    vehicle_id = int(request.form.get('vehicle_id'))

    try:
        execute_proc('sp_update_driver', (driver_id, license_no, fname, lname, age, vehicle_id))
        clear_cache()
        flash('Driver updated successfully!', 'success')
    except Exception as e:
        flash(f'Error updating driver: {str(e)}', 'danger')
    return redirect(url_for('employee_drivers'))


@app.route('/employee/drivers/delete/<int:driver_id>', methods=['POST'])
@employee_required
def employee_delete_driver(driver_id):
    try:
        execute_proc('sp_delete_driver', (driver_id,))
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
        execute_proc('sp_assign_driver', (driver_id, vehicle_id))
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
        """(SELECT DATE_FORMAT(start_dt, '%b %Y') as month,
               DATE_FORMAT(start_dt, '%Y-%m') as month_key,
               SUM(premium) as total, 'Home' as type
           FROM vw_home_policies WHERE start_dt IS NOT NULL GROUP BY month_key, month)
           UNION ALL
           (SELECT DATE_FORMAT(start_dt, '%b %Y') as month,
               DATE_FORMAT(start_dt, '%Y-%m') as month_key,
               SUM(premium) as total, 'Auto' as type
           FROM vw_auto_policies WHERE start_dt IS NOT NULL GROUP BY month_key, month)
           ORDER BY month_key""",
        fetchall=True
    )
    return jsonify([{k: float(v) if isinstance(v, Decimal) else v for k, v in row.items()} for row in data])


@app.route('/api/chart/policy-distribution')
@login_required
def api_policy_distribution():
    home_active = execute_query("SELECT COUNT(*) as cnt FROM vw_home_policies WHERE status_code='C'", fetchone=True)
    home_expired = execute_query("SELECT COUNT(*) as cnt FROM vw_home_policies WHERE status_code='E'", fetchone=True)
    auto_active = execute_query("SELECT COUNT(*) as cnt FROM vw_auto_policies WHERE status_code='C'", fetchone=True)
    auto_expired = execute_query("SELECT COUNT(*) as cnt FROM vw_auto_policies WHERE status_code='E'", fetchone=True)
    return jsonify({
        'labels': ['Home Active', 'Home Expired', 'Auto Active', 'Auto Expired'],
        'data': [home_active['cnt'], home_expired['cnt'], auto_active['cnt'], auto_expired['cnt']]
    })


@app.route('/api/chart/customer-by-state')
@login_required
def api_customer_by_state():
    data = execute_query(
        "SELECT STATE, COUNT(*) as cnt FROM vw_customer_directory GROUP BY STATE ORDER BY cnt DESC",
        fetchall=True
    )
    return jsonify({'labels': [r['STATE'] for r in data], 'data': [r['cnt'] for r in data]})


@app.route('/api/chart/payment-methods')
@login_required
def api_payment_methods():
    data = execute_query(
        "SELECT method, COUNT(*) as cnt FROM vw_all_payments GROUP BY method ORDER BY cnt DESC",
        fetchall=True
    )
    return jsonify({'labels': [r['method'] for r in data], 'data': [int(r['cnt']) for r in data]})


@app.route('/api/chart/top-customers')
@login_required
def api_top_customers():
    data = execute_query(
        """SELECT FIRST_NAME, LAST_NAME, fn_total_premium(customer_ref) as total_premium
           FROM vw_customer_directory
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
                   SELECT DATE_FORMAT(pay_date, '%Y-%m') AS month_key, amount
                   FROM vw_all_payments WHERE pay_date IS NOT NULL
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
    home_total = execute_query("SELECT COUNT(*) as cnt FROM vw_home_invoices", fetchone=True)
    auto_total = execute_query("SELECT COUNT(*) as cnt FROM vw_auto_invoices", fetchone=True)
    home_paid = execute_query("SELECT COUNT(*) as cnt FROM vw_home_invoices WHERE paid_amount >= amount_due", fetchone=True)
    auto_paid = execute_query("SELECT COUNT(*) as cnt FROM vw_auto_invoices WHERE paid_amount >= amount_due", fetchone=True)
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
        """SELECT DATE_FORMAT(pay_date, '%Y-%m') as month, SUM(amount) as total
           FROM vw_all_payments
           WHERE customer_ref = %s
           GROUP BY month ORDER BY month""",
        (cust_id,), fetchall=True
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
        "SELECT COALESCE(SUM(premium), 0) as total FROM vw_home_policies WHERE customer_ref=%s AND status_code='C'",
        (cust_id,), fetchone=True
    )
    auto_total = execute_query(
        "SELECT COALESCE(SUM(premium), 0) as total FROM vw_auto_policies WHERE customer_ref=%s AND status_code='C'",
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
        'RAH_DRIVER', 'RAH_HOME', 'RAH_USER', 'RAH_LOGIN_HISTORY',
        'RAH_POLICY_AUDIT', 'RAH_PASSWORD_RESET'
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
