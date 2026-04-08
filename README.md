# NICE Insurance Web Application

**CS-GY 6083 - Database Systems - Part II**  
NYU Tandon School of Engineering

## Overview

A full-stack insurance management web application built with Flask + MySQL + Bootstrap 5 + Chart.js. Features role-based access control (customers and employees), full CRUD operations on all entities, data visualizations, stored procedures, triggers, and comprehensive security.

## Prerequisites

- **Conda** (Miniconda or Anaconda) — for the Python environment
- **Homebrew** — for MySQL on macOS
- **MySQL 9.x** (installed via Homebrew)

## Quick Setup

### 1. Create Conda Environment & Install Python Dependencies

```bash
conda create -n dbmsProj python=3.11 -y
conda activate dbmsProj
pip install -r requirements.txt
```

### 2. Install & Start MySQL (macOS via Homebrew)

```bash
brew install mysql
brew services start mysql   # starts now and auto-starts on login
```

### 3. Set Up the Database

```bash
mysql -uroot < setup_database.sql
```

This creates the `nice_insurance` database with:
- 16 tables (12 original + 4 new for Part 2)
- 13 strategic indexes with comments
- 4 stored procedures
- 2 user-defined functions
- 6 audit triggers
- Sample data (15+ rows per table)
- Pre-configured user accounts

### 4. Configure Database Connection

The default `config.py` works out of the box with a Homebrew MySQL install (no root password). Edit it only if your credentials differ:

```python
MYSQL_HOST = 'localhost'
MYSQL_USER = 'root'
MYSQL_PASSWORD = ''  # default for Homebrew MySQL
MYSQL_DATABASE = 'nice_insurance'
MYSQL_PORT = 3306
```

Or use environment variables:
```bash
export MYSQL_PASSWORD='yourpassword'
```

### 5. Run the Application

```bash
conda activate dbmsProj
python app.py
```

The app starts at **http://localhost:8080**

> **Note:** Port 8080 is used instead of 5000 because macOS reserves port 5000 for AirPlay Receiver (Control Center). You can override the port with `PORT=5001 python app.py` if needed.

## Default Credentials

| Username    | Password      | Role     | Description              |
|-------------|---------------|----------|--------------------------|
| employee1   | password123   | Employee | Full admin access        |
| customer1   | password123   | Customer | James Anderson (ID: 1)   |
| customer2   | password123   | Customer | Sarah Martinez (ID: 2)   |

## Features

### Authentication & Security
- Bcrypt password hashing
- Role-based access control (Customer / Employee)
- Account lockout after 5 failed login attempts
- Login history tracking
- Security question for password reset
- CSRF token protection
- Session timeout (30 minutes)
- Parameterized SQL queries (prevent SQL injection)
- HTML escaping (prevent XSS)

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
- **Drivers**: Full CRUD, assign drivers to vehicles
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
- **Stored Procedures**: sp_process_payment, sp_renew_policy, sp_get_customer_summary, sp_generate_invoice
- **User Functions**: fn_total_premium, fn_outstanding_balance
- **Triggers**: 6 audit triggers on home and auto policy tables (INSERT, UPDATE, DELETE)
- **Indexes**: 13 strategic indexes with documented rationale
- **EXPLAIN Analysis**: Interactive page showing query execution plans

### Extra Credit
- ✅ 6+ data visualization charts with Chart.js
- ✅ 13 strategic indexes with EXPLAIN analysis page
- ✅ Comprehensive security (lockout, login history, CSRF, bcrypt)
- ✅ 4 stored procedures with transactions
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
