# NICE Insurance Web Application

**CS-GY 6083 - Database Systems - Part II**  
NYU Tandon School of Engineering

## Overview

A full-stack insurance management web application built with Flask + MySQL + Bootstrap 5 + Chart.js. Features role-based access control (customers and employees), full CRUD operations on all entities, data visualizations, stored procedures, triggers, and comprehensive security.

## Prerequisites

- **Python 3.10+** (3.11 recommended)
- **MySQL 8.0+** (MySQL 9.x also supported)
- **pip** (bundled with Python) or **Conda** (Miniconda/Anaconda) for managing the Python environment
- **Git** (to clone the repo)

## Quick Setup

### 1. Create a Python Environment & Install Dependencies

You can use either the built-in `venv` module (recommended for simplicity) or Conda. Pick whichever you already use — both work on macOS, Linux, and Windows.

<details>
<summary><b>Option A — Python <code>venv</code> (recommended, no extra tools)</b></summary>

**macOS / Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

**Windows (PowerShell):**
```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

> If PowerShell blocks the activation script, run once:
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

**Windows (Command Prompt / cmd):**
```bat
py -3.11 -m venv .venv
.venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
```

</details>

<details>
<summary><b>Option B — Conda (Miniconda / Anaconda)</b></summary>

Works the same on macOS, Linux, and Windows (use **Anaconda Prompt** on Windows):
```bash
conda create -n dbmsProj python=3.11 -y
conda activate dbmsProj
pip install -r requirements.txt
```

</details>

<details>
<summary><b>Option C — <code>uv</code> (fast modern alternative)</b></summary>

```bash
uv venv --python 3.11
# macOS/Linux:
source .venv/bin/activate
# Windows PowerShell:
.\.venv\Scripts\Activate.ps1

uv pip install -r requirements.txt
```

</details>

### 2. Install & Start MySQL

<details>
<summary><b>macOS (Homebrew)</b></summary>

```bash
brew install mysql
brew services start mysql   # starts now and auto-starts on login
```

Default root user has **no password** on Homebrew installs.

</details>

<details>
<summary><b>Windows</b></summary>

1. Download the **MySQL Installer for Windows** from <https://dev.mysql.com/downloads/installer/>.
2. Run it and choose **Server only** (or **Developer Default**).
3. During setup, set a **root password** (remember it — you'll put it in `config.py`).
4. Finish the wizard; MySQL is installed as a Windows service and starts automatically.
5. Make sure `mysql.exe` is on your `PATH` (usually `C:\Program Files\MySQL\MySQL Server 8.0\bin`), or use **MySQL 8.0 Command Line Client** from the Start menu.

</details>

<details>
<summary><b>Linux (Debian/Ubuntu)</b></summary>

```bash
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql
sudo mysql_secure_installation   # optional, to set a root password
```

</details>

### 3. Set Up the Database

**macOS / Linux:**
```bash
mysql -uroot < setup_database.sql
```

**Windows (PowerShell or cmd):**
```bat
mysql -uroot -p < setup_database.sql
```
(You'll be prompted for the root password you chose during installation.)

This creates the `nice_insurance` database with:
- 14 tables (10 updated core DDL tables + 4 application extension tables)
- 15 strategic indexes with comments
- 26 stored procedures for application DML and reporting actions
- 11 read-only security views for customer, policy, invoice, payment, vehicle, driver, and audit reads
- 2 user-defined functions
- 10 triggers (4 converted arc/discriminator triggers + 6 audit triggers)
- Sample data (15+ rows per table)
- Pre-configured user accounts

### 4. Configure Database Connection

The default `config.py` works out of the box with a Homebrew MySQL install (no root password). On Windows/Linux you'll usually need to set your root password. Edit `config.py`:

```python
MYSQL_HOST = 'localhost'
MYSQL_USER = 'root'
MYSQL_PASSWORD = ''          # e.g. 'yourpassword' on Windows/Linux
MYSQL_DATABASE = 'nice_insurance'
MYSQL_PORT = 3306
MYSQL_POOL_SIZE = 20         # supports concurrent dashboard chart/count requests
```

Or set it via environment variables (keeps secrets out of the repo):

**macOS / Linux (bash/zsh):**
```bash
export MYSQL_PASSWORD='yourpassword'
export MYSQL_POOL_SIZE=20
```

**Windows (PowerShell):**
```powershell
$env:MYSQL_PASSWORD = "yourpassword"
```

**Windows (cmd):**
```bat
set MYSQL_PASSWORD=yourpassword
```

### 5. Run the Application

Make sure your environment is activated, then:
```bash
python app.py
```

The app starts at **http://localhost:8080**

> **Note:** Port 8080 is used instead of 5000 because macOS reserves port 5000 for AirPlay Receiver (Control Center). You can override the port on any OS:
> - macOS/Linux: `PORT=5001 python app.py`
> - Windows PowerShell: `$env:PORT="5001"; python app.py`
> - Windows cmd: `set PORT=5001 && python app.py`

### 6. Run with Docker (Flask + MySQL)

Requirements: **Docker Desktop** (or Docker Engine + Compose v2).

```bash
# Optional: customize root password / host ports (defaults match docker-compose.yml)
cp .env.docker.example .env

docker compose up --build
```

- **App:** http://localhost:8080 (override with `WEB_PUBLISH_PORT` in `.env`).
- **MySQL on the host:** `localhost:${MYSQL_PUBLISH_PORT:-3307}` (mapped so it does not conflict with a local MySQL on 3306).

On first startup, MySQL initializes from `setup_database.sql` mounted into `/docker-entrypoint-initdb.d/`. Sample users match the **Default Credentials** section below.

To wipe the Docker database volume and re-seed:

```bash
docker compose down -v
docker compose up --build
```

## Default Credentials

| Username    | Password      | Role     | Description              |
|-------------|---------------|----------|--------------------------|
| employee1   | password123   | Employee | Full admin access        |
| customer1   | password123   | Customer | James Anderson, Home customer (ID: 1) |
| customer2   | password123   | Customer | Sarah Martinez, Auto customer (ID: 22) |

## Features

### Authentication & Security
- Bcrypt password hashing
- Role-based access control (Customer / Employee)
- Account lockout after 5 failed login attempts
- Login history tracking
- Security question for password reset
- CSRF token protection
- Session timeout (30 minutes)
- Stored procedure calls for application writes, with parameterized read queries
- Read-only views for main customer/employee reads so UI code does not depend on raw table joins
- HTML escaping (prevent XSS)

### Updated Core DDL Model
- Converted the latest Oracle Data Modeler DDL to MySQL.
- `RAH_CUSTOMER` now stores a single `CUST_TYPE` discriminator (`H` or `A`) directly on the customer row.
- `RAH_HOME_POLICY` and `RAH_AUTO_POLICY` now carry their own `CUST_TYPE` column and reference customers through `(CUST_ID, CUST_TYPE)`.
- Oracle arc triggers were converted to MySQL `BEFORE INSERT` / `BEFORE UPDATE` triggers using `SIGNAL SQLSTATE '45000'`.
- `RAH_DRIVER` now references `RAH_VEHICLE` directly through `VEHICLE_ID`; the old many-to-many vehicle-driver join table is no longer part of the core model.

### Customer Portal
- **Dashboard**: Summary stats, payment history chart, premium distribution chart
- **Policies**: View all home and auto policies with details
- **Invoices**: View invoices with payment status (paid/partial/unpaid)
- **Payments**: Make payments via stored procedure, view payment history
- **Vehicles**: View registered vehicles and assigned drivers
- **Profile**: Update address information

### Employee Portal
- **Dashboard**: Total customers, active policies, revenue, outstanding balance, 5 interactive charts, audit trail
- **Customers**: Full CRUD with search, pagination, modal forms
- **Policies**: Full CRUD for home and auto policies, policy renewal via stored procedure
- **Invoices**: View all invoices, generate new via stored procedure
- **Payments**: View all payment records across customers
- **Vehicles**: Full CRUD with policy assignment
- **Drivers**: Full CRUD, assign or reassign each driver to a vehicle
- **Reports**: 7 interactive charts with key business metrics
- **Index Analysis**: View all custom indexes, run EXPLAIN queries, see performance rationale

### Data Visualizations (6+ charts)
1. Monthly Revenue Trend (Line chart)
2. Policy Type Distribution - Home vs Auto (Pie chart)
3. Customers by State (Bar chart)
4. Payment Methods Breakdown (Doughnut chart)
5. Top 10 Customers by Premium (Horizontal bar chart)
6. Invoice Status Overview (Bar chart)
7. Premium Revenue by Month - Home vs Auto (Grouped bar chart)
8. Customer Payment History (Bar chart)
9. Customer Premium Distribution (Doughnut chart)

### Database Features
- **Stored Procedures**: 26 procedures cover payment processing, renewals, invoice generation, login/reset logging, registration, customer CRUD, policy CRUD, vehicle CRUD, and driver assignment.
- **Security Views**: 11 `vw_*` views expose aliased read models for customers, policies, invoices, payments, vehicles, drivers, dashboards, and audit trail data.
- **User Functions**: fn_total_premium, fn_outstanding_balance
- **Triggers**: 4 arc/discriminator triggers plus 6 audit triggers on home and auto policy tables (INSERT, UPDATE, DELETE)
- **Indexes**: 15 strategic indexes with documented rationale
- **EXPLAIN Analysis**: Interactive page showing query execution plans

### Extra Credit
- ✅ 6+ data visualization charts with Chart.js
- ✅ 15 strategic indexes with EXPLAIN analysis page
- ✅ Comprehensive security (lockout, login history, CSRF, bcrypt)
- ✅ 26 stored procedures with transactions for write operations
- ✅ 11 read-only views for secured, abstracted read access
- ✅ 2 user-defined functions
- ✅ Audit/history tables with triggers
- ✅ Simple caching for frequently accessed data

## Architecture

```
Flask (Python) ←→ MySQL 8.0
    ├── Templates (Jinja2 + Bootstrap 5)
    ├── Static (CSS + Chart.js + JavaScript)
    └── RESTful API routes (JSON for charts)
```

### Technology Stack
- **Backend**: Python Flask 3.0
- **Database**: MySQL 8.0+ with mysql-connector-python
- **Frontend**: HTML5, Bootstrap 5.3, Chart.js 4.4
- **Security**: bcrypt, parameterized queries, CSRF tokens

## Project Structure

```
nice_insurance_app/
├── app.py                  # Main Flask application (all routes)
├── config.py               # Database configuration
├── Dockerfile              # Flask app image
├── docker-compose.yml      # MySQL + web stack
├── requirements.txt        # Python dependencies
├── setup_database.sql      # Complete DDL + data + procedures + triggers
├── static/
│   ├── css/style.css       # Custom styles
│   └── js/
│       ├── main.js         # Common utilities
│       ├── charts.js       # Chart.js helpers
│       └── dashboard.js    # Dashboard interactions
├── templates/
│   ├── base.html           # Base template with navbar
│   ├── login.html          # Login + password reset
│   ├── register.html       # Registration with validation
│   ├── customer/           # Customer portal templates
│   └── employee/           # Employee portal templates
└── README.md
```
