-- ============================================================
-- NICE Insurance Database - CS-GY 6083 Part II
-- Complete DDL + Sample Data + Stored Procedures + Triggers
-- ============================================================

DROP DATABASE IF EXISTS nice_insurance;
CREATE DATABASE nice_insurance CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nice_insurance;

-- ============================================================
-- 1. TABLE DEFINITIONS (16 tables)
-- ============================================================

-- Table 1: RAH_CUSTOMER
CREATE TABLE RAH_CUSTOMER (
    CUST_ID INT PRIMARY KEY,
    FIRST_NAME VARCHAR(50) NOT NULL,
    MIDDLE_NAME VARCHAR(50) NULL,
    LAST_NAME VARCHAR(50) NOT NULL,
    ADDR_LINE1 VARCHAR(100) NOT NULL,
    ADDR_LINE2 VARCHAR(100) NULL,
    CITY VARCHAR(50) NOT NULL,
    STATE VARCHAR(2) NOT NULL,
    ZIP VARCHAR(5) NOT NULL,
    GENDER CHAR(1) NULL,
    MARITAL_STATUS CHAR(1) NOT NULL,
    CONSTRAINT chk_gender CHECK (GENDER IN ('M', 'F') OR GENDER IS NULL),
    CONSTRAINT chk_marital CHECK (MARITAL_STATUS IN ('M', 'S', 'W'))
);

-- Table 2: RAH_CUST_TYPE
CREATE TABLE RAH_CUST_TYPE (
    CUST_ID INT NOT NULL,
    CUST_TYPE CHAR(1) NOT NULL,
    PRIMARY KEY (CUST_ID, CUST_TYPE),
    CONSTRAINT fk_custtype_cust FOREIGN KEY (CUST_ID) REFERENCES RAH_CUSTOMER(CUST_ID) ON DELETE CASCADE,
    CONSTRAINT chk_cust_type CHECK (CUST_TYPE IN ('A', 'H'))
);

-- Table 3: RAH_HOME_POLICY
CREATE TABLE RAH_HOME_POLICY (
    HPOLICY_ID INT PRIMARY KEY,
    HPOLICY_START_DT DATE NOT NULL,
    HPOLICY_END_DT DATE NOT NULL,
    HPREMIUM_AMT DECIMAL(12,2) NOT NULL,
    HPOLICY_STATUS CHAR(1) NOT NULL,
    CUST_ID INT NOT NULL,
    CONSTRAINT fk_hpolicy_cust FOREIGN KEY (CUST_ID) REFERENCES RAH_CUSTOMER(CUST_ID) ON DELETE CASCADE,
    CONSTRAINT chk_hpolicy_dt CHECK (HPOLICY_END_DT > HPOLICY_START_DT),
    CONSTRAINT chk_hpremium CHECK (HPREMIUM_AMT > 0),
    CONSTRAINT chk_hpolicy_status CHECK (HPOLICY_STATUS IN ('C', 'E'))
);

-- Table 4: RAH_HOME
CREATE TABLE RAH_HOME (
    HOME_ID INT PRIMARY KEY,
    HOME_PURCHASE_DT DATE NOT NULL,
    HOME_PURCHASE_VAL DECIMAL(14,2) NOT NULL,
    HOME_AREA_SQFT DECIMAL(10,2) NOT NULL,
    HOME_TYPE CHAR(1) NOT NULL,
    AUTO_FIRE_NOTIF TINYINT NOT NULL,
    HOME_SECURITY_SYS TINYINT NOT NULL,
    SWIMMING_POOL CHAR(1) NULL,
    BASEMENT TINYINT NOT NULL,
    HPOLICY_ID INT NOT NULL,
    CONSTRAINT fk_home_hpolicy FOREIGN KEY (HPOLICY_ID) REFERENCES RAH_HOME_POLICY(HPOLICY_ID) ON DELETE CASCADE,
    CONSTRAINT chk_home_val CHECK (HOME_PURCHASE_VAL > 0),
    CONSTRAINT chk_home_area CHECK (HOME_AREA_SQFT > 0),
    CONSTRAINT chk_home_type CHECK (HOME_TYPE IN ('S', 'M', 'C', 'T')),
    CONSTRAINT chk_fire_notif CHECK (AUTO_FIRE_NOTIF IN (0, 1)),
    CONSTRAINT chk_security_sys CHECK (HOME_SECURITY_SYS IN (0, 1)),
    CONSTRAINT chk_pool CHECK (SWIMMING_POOL IN ('U', 'O', 'I', 'M') OR SWIMMING_POOL IS NULL),
    CONSTRAINT chk_basement CHECK (BASEMENT IN (0, 1))
);

-- Table 5: RAH_HOME_INVOICE
CREATE TABLE RAH_HOME_INVOICE (
    HINVOICE_ID INT PRIMARY KEY,
    HINVOICE_DT DATE NOT NULL,
    HINVOICE_DUE_DT DATE NOT NULL,
    HINVOICE_AMT DECIMAL(12,2) NOT NULL,
    HPOLICY_ID INT NOT NULL,
    CONSTRAINT fk_hinvoice_hpolicy FOREIGN KEY (HPOLICY_ID) REFERENCES RAH_HOME_POLICY(HPOLICY_ID) ON DELETE CASCADE,
    CONSTRAINT chk_hinv_amt CHECK (HINVOICE_AMT > 0),
    CONSTRAINT chk_hinv_dt CHECK (HINVOICE_DUE_DT > HINVOICE_DT)
);

-- Table 6: RAH_HOME_PAYMENT
CREATE TABLE RAH_HOME_PAYMENT (
    HPAYMENT_ID INT PRIMARY KEY,
    HPAYMENT_DT DATE NOT NULL,
    HPAYMENT_AMT DECIMAL(12,2) NOT NULL,
    HPAYMENT_METHOD VARCHAR(10) NOT NULL,
    HINVOICE_ID INT NOT NULL,
    CONSTRAINT fk_hpayment_hinvoice FOREIGN KEY (HINVOICE_ID) REFERENCES RAH_HOME_INVOICE(HINVOICE_ID) ON DELETE CASCADE,
    CONSTRAINT chk_hpay_amt CHECK (HPAYMENT_AMT > 0),
    CONSTRAINT chk_hpay_method CHECK (HPAYMENT_METHOD IN ('PayPal', 'Credit', 'Debit', 'Check'))
);

-- Table 7: RAH_AUTO_POLICY
CREATE TABLE RAH_AUTO_POLICY (
    APOLICY_ID INT PRIMARY KEY,
    APOLICY_START_DT DATE NOT NULL,
    APOLICY_END_DT DATE NOT NULL,
    APREMIUM_AMT DECIMAL(12,2) NOT NULL,
    APOLICY_STATUS CHAR(1) NOT NULL,
    CUST_ID INT NOT NULL,
    CONSTRAINT fk_apolicy_cust FOREIGN KEY (CUST_ID) REFERENCES RAH_CUSTOMER(CUST_ID) ON DELETE CASCADE,
    CONSTRAINT chk_apolicy_dt CHECK (APOLICY_END_DT > APOLICY_START_DT),
    CONSTRAINT chk_apremium CHECK (APREMIUM_AMT > 0),
    CONSTRAINT chk_apolicy_status CHECK (APOLICY_STATUS IN ('C', 'E'))
);

-- Table 8: RAH_AUTO_INVOICE
CREATE TABLE RAH_AUTO_INVOICE (
    AINVOICE_ID INT PRIMARY KEY,
    AINVOICE_DT DATE NOT NULL,
    AINVOICE_DUE_DT DATE NOT NULL,
    AINVOICE_AMT DECIMAL(12,2) NOT NULL,
    APOLICY_ID INT NOT NULL,
    CONSTRAINT fk_ainvoice_apolicy FOREIGN KEY (APOLICY_ID) REFERENCES RAH_AUTO_POLICY(APOLICY_ID) ON DELETE CASCADE,
    CONSTRAINT chk_ainv_amt CHECK (AINVOICE_AMT > 0),
    CONSTRAINT chk_ainv_dt CHECK (AINVOICE_DUE_DT > AINVOICE_DT)
);

-- Table 9: RAH_AUTO_PAYMENT
CREATE TABLE RAH_AUTO_PAYMENT (
    APAYMENT_ID INT PRIMARY KEY,
    APAYMENT_DT DATE NOT NULL,
    APAYMENT_AMT DECIMAL(12,2) NOT NULL,
    APAYMENT_METHOD VARCHAR(10) NOT NULL,
    AINVOICE_ID INT NOT NULL,
    CONSTRAINT fk_apayment_ainvoice FOREIGN KEY (AINVOICE_ID) REFERENCES RAH_AUTO_INVOICE(AINVOICE_ID) ON DELETE CASCADE,
    CONSTRAINT chk_apay_amt CHECK (APAYMENT_AMT > 0),
    CONSTRAINT chk_apay_method CHECK (APAYMENT_METHOD IN ('PayPal', 'Credit', 'Debit', 'Check'))
);

-- Table 10: RAH_VEHICLE
CREATE TABLE RAH_VEHICLE (
    VEHICLE_ID INT PRIMARY KEY,
    VEHICLE_VIN VARCHAR(17) NOT NULL UNIQUE,
    VEHICLE_MAKE VARCHAR(50) NOT NULL,
    VEHICLE_MODEL VARCHAR(50) NOT NULL,
    VEHICLE_YEAR SMALLINT NOT NULL,
    VEHICLE_STATUS CHAR(1) NOT NULL,
    APOLICY_ID INT NOT NULL,
    CONSTRAINT fk_vehicle_apolicy FOREIGN KEY (APOLICY_ID) REFERENCES RAH_AUTO_POLICY(APOLICY_ID) ON DELETE CASCADE,
    CONSTRAINT chk_veh_year CHECK (VEHICLE_YEAR >= 1886),
    CONSTRAINT chk_vin_len CHECK (CHAR_LENGTH(VEHICLE_VIN) = 17),
    CONSTRAINT chk_vehicle_status CHECK (VEHICLE_STATUS IN ('L', 'F', 'O'))
);

-- Table 11: RAH_DRIVER
CREATE TABLE RAH_DRIVER (
    DRIVER_ID INT PRIMARY KEY,
    DRIVER_LICENSE_NO VARCHAR(20) NOT NULL UNIQUE,
    DRIVER_FNAME VARCHAR(50) NOT NULL,
    DRIVER_LNAME VARCHAR(50) NOT NULL,
    DRIVER_AGE INT NOT NULL,
    CONSTRAINT chk_driver_age CHECK (DRIVER_AGE >= 16)
);

-- Table 12: RAH_VEHICLE_DRIVER
CREATE TABLE RAH_VEHICLE_DRIVER (
    VEHICLE_ID INT NOT NULL,
    DRIVER_ID INT NOT NULL,
    PRIMARY KEY (VEHICLE_ID, DRIVER_ID),
    CONSTRAINT fk_vd_vehicle FOREIGN KEY (VEHICLE_ID) REFERENCES RAH_VEHICLE(VEHICLE_ID) ON DELETE CASCADE,
    CONSTRAINT fk_vd_driver FOREIGN KEY (DRIVER_ID) REFERENCES RAH_DRIVER(DRIVER_ID) ON DELETE CASCADE
);

-- Table 13: RAH_USER (New for Part 2)
CREATE TABLE RAH_USER (
    USER_ID INT AUTO_INCREMENT PRIMARY KEY,
    USERNAME VARCHAR(50) NOT NULL UNIQUE,
    PASSWORD_HASH VARCHAR(255) NOT NULL,
    EMAIL VARCHAR(100) NOT NULL UNIQUE,
    ROLE ENUM('customer', 'employee') NOT NULL,
    CUST_ID INT NULL,
    SECURITY_QUESTION VARCHAR(255),
    SECURITY_ANSWER_HASH VARCHAR(255),
    FAILED_LOGIN_ATTEMPTS INT DEFAULT 0,
    ACCOUNT_LOCKED TINYINT DEFAULT 0,
    LAST_LOGIN DATETIME NULL,
    CREATED_AT DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_cust FOREIGN KEY (CUST_ID) REFERENCES RAH_CUSTOMER(CUST_ID) ON DELETE SET NULL
);

-- Table 14: RAH_LOGIN_HISTORY (New for Part 2)
CREATE TABLE RAH_LOGIN_HISTORY (
    LOG_ID INT AUTO_INCREMENT PRIMARY KEY,
    USER_ID INT NOT NULL,
    LOGIN_DT DATETIME NOT NULL,
    IP_ADDRESS VARCHAR(45),
    SUCCESS TINYINT NOT NULL,
    CONSTRAINT fk_loghistory_user FOREIGN KEY (USER_ID) REFERENCES RAH_USER(USER_ID) ON DELETE CASCADE
);

-- Table 15: RAH_POLICY_AUDIT (New for Part 2)
CREATE TABLE RAH_POLICY_AUDIT (
    AUDIT_ID INT AUTO_INCREMENT PRIMARY KEY,
    TABLE_NAME VARCHAR(50) NOT NULL,
    RECORD_ID INT NOT NULL,
    ACTION ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    OLD_VALUES JSON NULL,
    NEW_VALUES JSON NULL,
    CHANGED_BY VARCHAR(50),
    CHANGED_AT DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Table 16: RAH_PASSWORD_RESET (New for Part 2)
CREATE TABLE RAH_PASSWORD_RESET (
    RESET_ID INT AUTO_INCREMENT PRIMARY KEY,
    USER_ID INT NOT NULL,
    RESET_TOKEN VARCHAR(255) NOT NULL,
    EXPIRES_AT DATETIME NOT NULL,
    USED TINYINT DEFAULT 0,
    CREATED_AT DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_pwreset_user FOREIGN KEY (USER_ID) REFERENCES RAH_USER(USER_ID) ON DELETE CASCADE
);


-- ============================================================
-- 2. STRATEGIC INDEXES (with rationale)
-- ============================================================

-- Frequent filtering by state for reports and analytics
CREATE INDEX idx_customer_state ON RAH_CUSTOMER(STATE);

-- Frequent filtering by city for geographic analytics
CREATE INDEX idx_customer_city ON RAH_CUSTOMER(CITY);

-- Join optimization: finding all home policies for a customer
CREATE INDEX idx_home_policy_cust ON RAH_HOME_POLICY(CUST_ID);

-- Status filtering: active vs expired policy lookups
CREATE INDEX idx_home_policy_status ON RAH_HOME_POLICY(HPOLICY_STATUS);

-- Join optimization: finding all auto policies for a customer
CREATE INDEX idx_auto_policy_cust ON RAH_AUTO_POLICY(CUST_ID);

-- Status filtering: active vs expired auto policy lookups
CREATE INDEX idx_auto_policy_status ON RAH_AUTO_POLICY(APOLICY_STATUS);

-- Join optimization: linking invoices to home policies
CREATE INDEX idx_home_invoice_policy ON RAH_HOME_INVOICE(HPOLICY_ID);

-- Join optimization: linking invoices to auto policies
CREATE INDEX idx_auto_invoice_policy ON RAH_AUTO_INVOICE(APOLICY_ID);

-- Join optimization: finding vehicles under an auto policy
CREATE INDEX idx_vehicle_policy ON RAH_VEHICLE(APOLICY_ID);

-- Role-based query optimization for user authentication
CREATE INDEX idx_user_role ON RAH_USER(ROLE);

-- Customer lookup optimization when loading user profiles
CREATE INDEX idx_user_custid ON RAH_USER(CUST_ID);

-- Login history lookups by user
CREATE INDEX idx_login_history_user ON RAH_LOGIN_HISTORY(USER_ID);

-- Audit table lookups by table name and record
CREATE INDEX idx_audit_table_record ON RAH_POLICY_AUDIT(TABLE_NAME, RECORD_ID);


-- ============================================================
-- 3. STORED PROCEDURES
-- ============================================================

DELIMITER //

-- SP 1: Process Payment (Home or Auto)
CREATE PROCEDURE sp_process_payment(
    IN p_payment_type VARCHAR(4),
    IN p_invoice_id INT,
    IN p_amount DECIMAL(12,2),
    IN p_method VARCHAR(10),
    IN p_payment_date DATE
)
BEGIN
    DECLARE v_next_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment processing failed';
    END;

    START TRANSACTION;

    IF p_payment_type = 'home' THEN
        SELECT COALESCE(MAX(HPAYMENT_ID), 0) + 1 INTO v_next_id FROM RAH_HOME_PAYMENT;
        INSERT INTO RAH_HOME_PAYMENT (HPAYMENT_ID, HPAYMENT_DT, HPAYMENT_AMT, HPAYMENT_METHOD, HINVOICE_ID)
        VALUES (v_next_id, p_payment_date, p_amount, p_method, p_invoice_id);
    ELSEIF p_payment_type = 'auto' THEN
        SELECT COALESCE(MAX(APAYMENT_ID), 0) + 1 INTO v_next_id FROM RAH_AUTO_PAYMENT;
        INSERT INTO RAH_AUTO_PAYMENT (APAYMENT_ID, APAYMENT_DT, APAYMENT_AMT, APAYMENT_METHOD, AINVOICE_ID)
        VALUES (v_next_id, p_payment_date, p_amount, p_method, p_invoice_id);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid payment type. Use home or auto.';
    END IF;

    COMMIT;
END //

-- SP 2: Renew Policy (creates new, expires old)
CREATE PROCEDURE sp_renew_policy(
    IN p_policy_type VARCHAR(4),
    IN p_old_policy_id INT,
    IN p_new_start DATE,
    IN p_new_end DATE,
    IN p_new_premium DECIMAL(12,2)
)
BEGIN
    DECLARE v_cust_id INT;
    DECLARE v_new_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Policy renewal failed';
    END;

    START TRANSACTION;

    IF p_policy_type = 'home' THEN
        SELECT CUST_ID INTO v_cust_id FROM RAH_HOME_POLICY WHERE HPOLICY_ID = p_old_policy_id;
        UPDATE RAH_HOME_POLICY SET HPOLICY_STATUS = 'E' WHERE HPOLICY_ID = p_old_policy_id;
        SELECT COALESCE(MAX(HPOLICY_ID), 0) + 1 INTO v_new_id FROM RAH_HOME_POLICY;
        INSERT INTO RAH_HOME_POLICY (HPOLICY_ID, HPOLICY_START_DT, HPOLICY_END_DT, HPREMIUM_AMT, HPOLICY_STATUS, CUST_ID)
        VALUES (v_new_id, p_new_start, p_new_end, p_new_premium, 'C', v_cust_id);
    ELSEIF p_policy_type = 'auto' THEN
        SELECT CUST_ID INTO v_cust_id FROM RAH_AUTO_POLICY WHERE APOLICY_ID = p_old_policy_id;
        UPDATE RAH_AUTO_POLICY SET APOLICY_STATUS = 'E' WHERE APOLICY_ID = p_old_policy_id;
        SELECT COALESCE(MAX(APOLICY_ID), 0) + 1 INTO v_new_id FROM RAH_AUTO_POLICY;
        INSERT INTO RAH_AUTO_POLICY (APOLICY_ID, APOLICY_START_DT, APOLICY_END_DT, APREMIUM_AMT, APOLICY_STATUS, CUST_ID)
        VALUES (v_new_id, p_new_start, p_new_end, p_new_premium, 'C', v_cust_id);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid policy type. Use home or auto.';
    END IF;

    COMMIT;
    SELECT v_new_id AS new_policy_id;
END //

-- SP 3: Get Customer Summary
CREATE PROCEDURE sp_get_customer_summary(IN p_cust_id INT)
BEGIN
    -- Customer info
    SELECT c.*, GROUP_CONCAT(ct.CUST_TYPE) AS customer_types
    FROM RAH_CUSTOMER c
    LEFT JOIN RAH_CUST_TYPE ct ON c.CUST_ID = ct.CUST_ID
    WHERE c.CUST_ID = p_cust_id
    GROUP BY c.CUST_ID;

    -- Home policies
    SELECT hp.*, h.HOME_TYPE, h.HOME_PURCHASE_VAL, h.HOME_AREA_SQFT
    FROM RAH_HOME_POLICY hp
    LEFT JOIN RAH_HOME h ON hp.HPOLICY_ID = h.HPOLICY_ID
    WHERE hp.CUST_ID = p_cust_id;

    -- Auto policies
    SELECT ap.*, COUNT(v.VEHICLE_ID) AS vehicle_count
    FROM RAH_AUTO_POLICY ap
    LEFT JOIN RAH_VEHICLE v ON ap.APOLICY_ID = v.APOLICY_ID
    WHERE ap.CUST_ID = p_cust_id
    GROUP BY ap.APOLICY_ID;

    -- Financial summary
    SELECT fn_total_premium(p_cust_id) AS total_premium,
           fn_outstanding_balance(p_cust_id) AS outstanding_balance;
END //

-- SP 4: Generate Invoice
CREATE PROCEDURE sp_generate_invoice(
    IN p_policy_type VARCHAR(4),
    IN p_policy_id INT,
    IN p_invoice_date DATE,
    IN p_due_date DATE,
    IN p_amount DECIMAL(12,2)
)
BEGIN
    DECLARE v_next_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice generation failed';
    END;

    START TRANSACTION;

    IF p_policy_type = 'home' THEN
        SELECT COALESCE(MAX(HINVOICE_ID), 0) + 1 INTO v_next_id FROM RAH_HOME_INVOICE;
        INSERT INTO RAH_HOME_INVOICE (HINVOICE_ID, HINVOICE_DT, HINVOICE_DUE_DT, HINVOICE_AMT, HPOLICY_ID)
        VALUES (v_next_id, p_invoice_date, p_due_date, p_amount, p_policy_id);
    ELSEIF p_policy_type = 'auto' THEN
        SELECT COALESCE(MAX(AINVOICE_ID), 0) + 1 INTO v_next_id FROM RAH_AUTO_INVOICE;
        INSERT INTO RAH_AUTO_INVOICE (AINVOICE_ID, AINVOICE_DT, AINVOICE_DUE_DT, AINVOICE_AMT, APOLICY_ID)
        VALUES (v_next_id, p_invoice_date, p_due_date, p_amount, p_policy_id);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid policy type. Use home or auto.';
    END IF;

    COMMIT;
    SELECT v_next_id AS new_invoice_id;
END //


-- ============================================================
-- 4. USER-DEFINED FUNCTIONS
-- ============================================================

-- Function 1: Total Premium for a Customer
CREATE FUNCTION fn_total_premium(p_cust_id INT)
RETURNS DECIMAL(14,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_home_total DECIMAL(14,2);
    DECLARE v_auto_total DECIMAL(14,2);

    SELECT COALESCE(SUM(HPREMIUM_AMT), 0) INTO v_home_total
    FROM RAH_HOME_POLICY WHERE CUST_ID = p_cust_id AND HPOLICY_STATUS = 'C';

    SELECT COALESCE(SUM(APREMIUM_AMT), 0) INTO v_auto_total
    FROM RAH_AUTO_POLICY WHERE CUST_ID = p_cust_id AND APOLICY_STATUS = 'C';

    RETURN v_home_total + v_auto_total;
END //

-- Function 2: Outstanding Balance for a Customer
CREATE FUNCTION fn_outstanding_balance(p_cust_id INT)
RETURNS DECIMAL(14,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_home_invoiced DECIMAL(14,2);
    DECLARE v_home_paid DECIMAL(14,2);
    DECLARE v_auto_invoiced DECIMAL(14,2);
    DECLARE v_auto_paid DECIMAL(14,2);

    SELECT COALESCE(SUM(hi.HINVOICE_AMT), 0) INTO v_home_invoiced
    FROM RAH_HOME_INVOICE hi
    JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
    WHERE hp.CUST_ID = p_cust_id;

    SELECT COALESCE(SUM(hpay.HPAYMENT_AMT), 0) INTO v_home_paid
    FROM RAH_HOME_PAYMENT hpay
    JOIN RAH_HOME_INVOICE hi ON hpay.HINVOICE_ID = hi.HINVOICE_ID
    JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
    WHERE hp.CUST_ID = p_cust_id;

    SELECT COALESCE(SUM(ai.AINVOICE_AMT), 0) INTO v_auto_invoiced
    FROM RAH_AUTO_INVOICE ai
    JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
    WHERE ap.CUST_ID = p_cust_id;

    SELECT COALESCE(SUM(apay.APAYMENT_AMT), 0) INTO v_auto_paid
    FROM RAH_AUTO_PAYMENT apay
    JOIN RAH_AUTO_INVOICE ai ON apay.AINVOICE_ID = ai.AINVOICE_ID
    JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
    WHERE ap.CUST_ID = p_cust_id;

    RETURN (v_home_invoiced + v_auto_invoiced) - (v_home_paid + v_auto_paid);
END //


-- ============================================================
-- 5. TRIGGERS (Audit Trail)
-- ============================================================

-- Home Policy Audit Triggers
CREATE TRIGGER trg_home_policy_audit_insert
AFTER INSERT ON RAH_HOME_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_HOME_POLICY', NEW.HPOLICY_ID, 'INSERT', NULL,
            JSON_OBJECT('HPOLICY_ID', NEW.HPOLICY_ID, 'HPOLICY_START_DT', NEW.HPOLICY_START_DT,
                        'HPOLICY_END_DT', NEW.HPOLICY_END_DT, 'HPREMIUM_AMT', NEW.HPREMIUM_AMT,
                        'HPOLICY_STATUS', NEW.HPOLICY_STATUS, 'CUST_ID', NEW.CUST_ID),
            CURRENT_USER(), NOW());
END //

CREATE TRIGGER trg_home_policy_audit_update
AFTER UPDATE ON RAH_HOME_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_HOME_POLICY', NEW.HPOLICY_ID, 'UPDATE',
            JSON_OBJECT('HPOLICY_ID', OLD.HPOLICY_ID, 'HPOLICY_START_DT', OLD.HPOLICY_START_DT,
                        'HPOLICY_END_DT', OLD.HPOLICY_END_DT, 'HPREMIUM_AMT', OLD.HPREMIUM_AMT,
                        'HPOLICY_STATUS', OLD.HPOLICY_STATUS, 'CUST_ID', OLD.CUST_ID),
            JSON_OBJECT('HPOLICY_ID', NEW.HPOLICY_ID, 'HPOLICY_START_DT', NEW.HPOLICY_START_DT,
                        'HPOLICY_END_DT', NEW.HPOLICY_END_DT, 'HPREMIUM_AMT', NEW.HPREMIUM_AMT,
                        'HPOLICY_STATUS', NEW.HPOLICY_STATUS, 'CUST_ID', NEW.CUST_ID),
            CURRENT_USER(), NOW());
END //

CREATE TRIGGER trg_home_policy_audit_delete
BEFORE DELETE ON RAH_HOME_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_HOME_POLICY', OLD.HPOLICY_ID, 'DELETE',
            JSON_OBJECT('HPOLICY_ID', OLD.HPOLICY_ID, 'HPOLICY_START_DT', OLD.HPOLICY_START_DT,
                        'HPOLICY_END_DT', OLD.HPOLICY_END_DT, 'HPREMIUM_AMT', OLD.HPREMIUM_AMT,
                        'HPOLICY_STATUS', OLD.HPOLICY_STATUS, 'CUST_ID', OLD.CUST_ID),
            NULL, CURRENT_USER(), NOW());
END //

-- Auto Policy Audit Triggers
CREATE TRIGGER trg_auto_policy_audit_insert
AFTER INSERT ON RAH_AUTO_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_AUTO_POLICY', NEW.APOLICY_ID, 'INSERT', NULL,
            JSON_OBJECT('APOLICY_ID', NEW.APOLICY_ID, 'APOLICY_START_DT', NEW.APOLICY_START_DT,
                        'APOLICY_END_DT', NEW.APOLICY_END_DT, 'APREMIUM_AMT', NEW.APREMIUM_AMT,
                        'APOLICY_STATUS', NEW.APOLICY_STATUS, 'CUST_ID', NEW.CUST_ID),
            CURRENT_USER(), NOW());
END //

CREATE TRIGGER trg_auto_policy_audit_update
AFTER UPDATE ON RAH_AUTO_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_AUTO_POLICY', NEW.APOLICY_ID, 'UPDATE',
            JSON_OBJECT('APOLICY_ID', OLD.APOLICY_ID, 'APOLICY_START_DT', OLD.APOLICY_START_DT,
                        'APOLICY_END_DT', OLD.APOLICY_END_DT, 'APREMIUM_AMT', OLD.APREMIUM_AMT,
                        'APOLICY_STATUS', OLD.APOLICY_STATUS, 'CUST_ID', OLD.CUST_ID),
            JSON_OBJECT('APOLICY_ID', NEW.APOLICY_ID, 'APOLICY_START_DT', NEW.APOLICY_START_DT,
                        'APOLICY_END_DT', NEW.APOLICY_END_DT, 'APREMIUM_AMT', NEW.APREMIUM_AMT,
                        'APOLICY_STATUS', NEW.APOLICY_STATUS, 'CUST_ID', NEW.CUST_ID),
            CURRENT_USER(), NOW());
END //

CREATE TRIGGER trg_auto_policy_audit_delete
BEFORE DELETE ON RAH_AUTO_POLICY
FOR EACH ROW
BEGIN
    INSERT INTO RAH_POLICY_AUDIT (TABLE_NAME, RECORD_ID, ACTION, OLD_VALUES, NEW_VALUES, CHANGED_BY, CHANGED_AT)
    VALUES ('RAH_AUTO_POLICY', OLD.APOLICY_ID, 'DELETE',
            JSON_OBJECT('APOLICY_ID', OLD.APOLICY_ID, 'APOLICY_START_DT', OLD.APOLICY_START_DT,
                        'APOLICY_END_DT', OLD.APOLICY_END_DT, 'APREMIUM_AMT', OLD.APREMIUM_AMT,
                        'APOLICY_STATUS', OLD.APOLICY_STATUS, 'CUST_ID', OLD.CUST_ID),
            NULL, CURRENT_USER(), NOW());
END //

DELIMITER ;


-- ============================================================
-- 6. SAMPLE DATA (15+ rows per table)
-- ============================================================

-- Customers (20 records)
INSERT INTO RAH_CUSTOMER VALUES
(1, 'James', 'Michael', 'Anderson', '142 Oak Street', 'Apt 3B', 'Brooklyn', 'NY', '11201', 'M', 'M'),
(2, 'Sarah', 'Elizabeth', 'Martinez', '89 Elm Avenue', NULL, 'Manhattan', 'NY', '10001', 'F', 'S'),
(3, 'Robert', NULL, 'Johnson', '567 Pine Road', 'Suite 200', 'Jersey City', 'NJ', '07302', 'M', 'M'),
(4, 'Emily', 'Rose', 'Williams', '234 Maple Drive', NULL, 'Stamford', 'CT', '06901', 'F', 'M'),
(5, 'Michael', 'David', 'Brown', '891 Cedar Lane', NULL, 'Philadelphia', 'PA', '19103', 'M', 'S'),
(6, 'Jessica', NULL, 'Davis', '456 Birch Street', 'Floor 2', 'Boston', 'MA', '02101', 'F', 'W'),
(7, 'William', 'Thomas', 'Garcia', '123 Spruce Ave', NULL, 'Newark', 'NJ', '07101', 'M', 'M'),
(8, 'Amanda', 'Lynn', 'Miller', '678 Walnut Blvd', NULL, 'Hartford', 'CT', '06103', 'F', 'S'),
(9, 'Daniel', NULL, 'Wilson', '345 Ash Court', 'Unit 5', 'Hoboken', 'NJ', '07030', 'M', 'S'),
(10, 'Jennifer', 'Marie', 'Taylor', '912 Poplar Way', NULL, 'White Plains', 'NY', '10601', 'F', 'M'),
(11, 'Christopher', 'James', 'Thomas', '567 Hickory Lane', NULL, 'Cambridge', 'MA', '02139', 'M', 'M'),
(12, 'Ashley', NULL, 'Jackson', '234 Dogwood Drive', 'Apt 12A', 'Queens', 'NY', '11375', 'F', 'S'),
(13, 'Matthew', 'Ryan', 'White', '891 Magnolia St', NULL, 'Trenton', 'NJ', '08608', 'M', 'W'),
(14, 'Stephanie', 'Ann', 'Harris', '456 Sycamore Rd', NULL, 'New Haven', 'CT', '06510', 'F', 'M'),
(15, 'Andrew', NULL, 'Clark', '123 Chestnut Ave', 'Suite 100', 'Providence', 'RI', '02903', 'M', 'S'),
(16, 'Nicole', 'Grace', 'Lewis', '678 Willow Lane', NULL, 'Bronx', 'NY', '10451', 'F', 'M'),
(17, 'Joshua', 'Allen', 'Robinson', '345 Redwood Ct', NULL, 'Edison', 'NJ', '08817', 'M', 'S'),
(18, 'Lauren', NULL, 'Walker', '912 Cypress Blvd', 'Apt 7C', 'Yonkers', 'NY', '10701', 'F', 'W'),
(19, 'Kevin', 'Patrick', 'Young', '567 Juniper Way', NULL, 'Worcester', 'MA', '01608', 'M', 'M'),
(20, 'Rachel', 'Anne', 'King', '234 Aspen Drive', NULL, 'Bridgeport', 'CT', '06604', 'F', 'S');

-- Customer Types (30 records - some customers have both)
INSERT INTO RAH_CUST_TYPE VALUES
(1, 'H'), (1, 'A'), (2, 'H'), (2, 'A'), (3, 'A'), (4, 'H'),
(5, 'A'), (5, 'H'), (6, 'H'), (7, 'A'), (8, 'H'), (8, 'A'),
(9, 'A'), (10, 'H'), (10, 'A'), (11, 'H'), (12, 'A'), (13, 'H'),
(14, 'A'), (14, 'H'), (15, 'A'), (16, 'H'), (17, 'A'), (18, 'H'),
(19, 'A'), (19, 'H'), (20, 'A');

-- Home Policies (18 records)
INSERT INTO RAH_HOME_POLICY VALUES
(1, '2022-01-15', '2023-01-15', 1250.00, 'E', 1),
(2, '2023-01-15', '2024-01-15', 1350.00, 'E', 1),
(3, '2023-03-01', '2024-03-01', 980.00, 'E', 2),
(4, '2024-03-01', '2025-03-01', 1050.00, 'C', 2),
(5, '2022-06-10', '2023-06-10', 1500.00, 'E', 4),
(6, '2023-06-10', '2024-06-10', 1620.00, 'C', 4),
(7, '2023-09-01', '2024-09-01', 890.00, 'C', 5),
(8, '2024-01-01', '2025-01-01', 1100.00, 'C', 6),
(9, '2022-11-15', '2023-11-15', 1450.00, 'E', 8),
(10, '2023-11-15', '2024-11-15', 1550.00, 'C', 8),
(11, '2024-02-01', '2025-02-01', 2100.00, 'C', 10),
(12, '2023-07-01', '2024-07-01', 1780.00, 'C', 11),
(13, '2024-04-15', '2025-04-15', 920.00, 'C', 13),
(14, '2023-08-01', '2024-08-01', 1350.00, 'C', 14),
(15, '2024-05-01', '2025-05-01', 1680.00, 'C', 16),
(16, '2023-12-01', '2024-12-01', 1200.00, 'C', 18),
(17, '2024-06-01', '2025-06-01', 1890.00, 'C', 19),
(18, '2024-01-15', '2026-01-15', 1420.00, 'C', 1);

-- Homes (18 records)
INSERT INTO RAH_HOME VALUES
(1, '2015-03-20', 450000.00, 1800.00, 'S', 1, 1, NULL, 1, 1),
(2, '2015-03-20', 450000.00, 1800.00, 'S', 1, 1, 'I', 1, 2),
(3, '2018-07-15', 320000.00, 1200.00, 'C', 0, 1, NULL, 0, 3),
(4, '2018-07-15', 320000.00, 1200.00, 'C', 1, 1, NULL, 0, 4),
(5, '2020-01-10', 580000.00, 2400.00, 'S', 1, 1, 'O', 1, 5),
(6, '2020-01-10', 580000.00, 2400.00, 'S', 1, 1, 'O', 1, 6),
(7, '2021-05-22', 275000.00, 1100.00, 'T', 0, 0, NULL, 0, 7),
(8, '2019-11-03', 410000.00, 1650.00, 'S', 1, 1, 'I', 1, 8),
(9, '2017-08-14', 520000.00, 2200.00, 'S', 1, 1, 'U', 1, 9),
(10, '2017-08-14', 520000.00, 2200.00, 'S', 1, 1, 'U', 1, 10),
(11, '2022-02-28', 680000.00, 2800.00, 'S', 1, 1, 'O', 1, 11),
(12, '2016-10-05', 390000.00, 1500.00, 'M', 1, 1, NULL, 0, 12),
(13, '2023-01-20', 210000.00, 950.00, 'C', 0, 0, NULL, 0, 13),
(14, '2019-06-12', 445000.00, 1750.00, 'S', 1, 1, 'I', 1, 14),
(15, '2021-09-30', 550000.00, 2100.00, 'S', 1, 1, 'O', 1, 15),
(16, '2020-04-18', 310000.00, 1300.00, 'T', 0, 1, NULL, 0, 16),
(17, '2022-07-25', 620000.00, 2600.00, 'S', 1, 1, 'U', 1, 17),
(18, '2015-03-20', 480000.00, 1850.00, 'S', 1, 1, 'I', 1, 18);

-- Home Invoices (25 records)
INSERT INTO RAH_HOME_INVOICE VALUES
(1, '2022-01-15', '2022-02-15', 312.50, 1),
(2, '2022-04-15', '2022-05-15', 312.50, 1),
(3, '2022-07-15', '2022-08-15', 312.50, 1),
(4, '2022-10-15', '2022-11-15', 312.50, 1),
(5, '2023-03-01', '2023-04-01', 245.00, 3),
(6, '2023-06-01', '2023-07-01', 245.00, 3),
(7, '2023-09-01', '2023-10-01', 245.00, 3),
(8, '2023-12-01', '2024-01-01', 245.00, 3),
(9, '2024-03-01', '2024-04-01', 262.50, 4),
(10, '2024-06-01', '2024-07-01', 262.50, 4),
(11, '2024-09-01', '2024-10-01', 262.50, 4),
(12, '2023-06-10', '2023-07-10', 405.00, 6),
(13, '2023-09-10', '2023-10-10', 405.00, 6),
(14, '2024-01-01', '2024-02-01', 275.00, 8),
(15, '2024-04-01', '2024-05-01', 275.00, 8),
(16, '2024-07-01', '2024-08-01', 275.00, 8),
(17, '2024-02-01', '2024-03-01', 525.00, 11),
(18, '2024-05-01', '2024-06-01', 525.00, 11),
(19, '2024-08-01', '2024-09-01', 525.00, 11),
(20, '2024-04-15', '2024-05-15', 230.00, 13),
(21, '2024-05-01', '2024-06-01', 420.00, 15),
(22, '2024-08-01', '2024-09-01', 420.00, 15),
(23, '2024-06-01', '2024-07-01', 472.50, 17),
(24, '2024-09-01', '2024-10-01', 472.50, 17),
(25, '2024-01-15', '2024-02-15', 355.00, 18);

-- Home Payments (20 records)
INSERT INTO RAH_HOME_PAYMENT VALUES
(1, '2022-02-10', 312.50, 'Credit', 1),
(2, '2022-05-12', 312.50, 'Credit', 2),
(3, '2022-08-10', 312.50, 'Debit', 3),
(4, '2022-11-08', 312.50, 'Credit', 4),
(5, '2023-03-28', 245.00, 'PayPal', 5),
(6, '2023-06-25', 245.00, 'PayPal', 6),
(7, '2023-09-20', 245.00, 'Check', 7),
(8, '2024-03-15', 262.50, 'Credit', 9),
(9, '2024-06-20', 262.50, 'Debit', 10),
(10, '2023-07-05', 405.00, 'Credit', 12),
(11, '2023-10-08', 405.00, 'Credit', 13),
(12, '2024-01-28', 275.00, 'PayPal', 14),
(13, '2024-04-25', 275.00, 'Debit', 15),
(14, '2024-02-20', 525.00, 'Credit', 17),
(15, '2024-05-22', 525.00, 'Credit', 18),
(16, '2024-05-10', 230.00, 'Check', 20),
(17, '2024-05-28', 420.00, 'Credit', 21),
(18, '2024-08-20', 420.00, 'Debit', 22),
(19, '2024-06-25', 472.50, 'PayPal', 23),
(20, '2024-02-10', 355.00, 'Credit', 25);

-- Auto Policies (18 records)
INSERT INTO RAH_AUTO_POLICY VALUES
(1, '2022-03-01', '2023-03-01', 850.00, 'E', 1),
(2, '2023-03-01', '2024-03-01', 920.00, 'E', 1),
(3, '2023-05-15', '2024-05-15', 750.00, 'C', 2),
(4, '2022-08-01', '2023-08-01', 680.00, 'E', 3),
(5, '2023-08-01', '2024-08-01', 730.00, 'C', 3),
(6, '2023-04-01', '2024-04-01', 1100.00, 'C', 5),
(7, '2024-01-15', '2025-01-15', 990.00, 'C', 7),
(8, '2023-10-01', '2024-10-01', 860.00, 'C', 8),
(9, '2024-02-01', '2025-02-01', 780.00, 'C', 9),
(10, '2023-06-01', '2024-06-01', 1200.00, 'C', 10),
(11, '2024-03-01', '2025-03-01', 650.00, 'C', 12),
(12, '2023-11-01', '2024-11-01', 1050.00, 'C', 14),
(13, '2024-04-01', '2025-04-01', 820.00, 'C', 15),
(14, '2024-05-15', '2025-05-15', 940.00, 'C', 17),
(15, '2023-07-01', '2024-07-01', 1150.00, 'C', 19),
(16, '2024-06-01', '2025-06-01', 710.00, 'C', 20),
(17, '2024-03-01', '2026-03-01', 950.00, 'C', 1),
(18, '2024-07-01', '2025-07-01', 880.00, 'C', 5);

-- Auto Invoices (25 records)
INSERT INTO RAH_AUTO_INVOICE VALUES
(1, '2022-03-01', '2022-04-01', 212.50, 1),
(2, '2022-06-01', '2022-07-01', 212.50, 1),
(3, '2022-09-01', '2022-10-01', 212.50, 1),
(4, '2022-12-01', '2023-01-01', 212.50, 1),
(5, '2023-05-15', '2023-06-15', 187.50, 3),
(6, '2023-08-15', '2023-09-15', 187.50, 3),
(7, '2023-11-15', '2023-12-15', 187.50, 3),
(8, '2023-08-01', '2023-09-01', 182.50, 5),
(9, '2023-11-01', '2023-12-01', 182.50, 5),
(10, '2024-02-01', '2024-03-01', 182.50, 5),
(11, '2023-04-01', '2023-05-01', 275.00, 6),
(12, '2023-07-01', '2023-08-01', 275.00, 6),
(13, '2024-01-15', '2024-02-15', 247.50, 7),
(14, '2024-04-15', '2024-05-15', 247.50, 7),
(15, '2024-02-01', '2024-03-01', 195.00, 9),
(16, '2024-05-01', '2024-06-01', 195.00, 9),
(17, '2023-06-01', '2023-07-01', 300.00, 10),
(18, '2023-09-01', '2023-10-01', 300.00, 10),
(19, '2024-03-01', '2024-04-01', 162.50, 11),
(20, '2024-04-01', '2024-05-01', 262.50, 12),
(21, '2024-04-01', '2024-05-01', 205.00, 13),
(22, '2024-05-15', '2024-06-15', 235.00, 14),
(23, '2024-06-01', '2024-07-01', 177.50, 16),
(24, '2024-03-01', '2024-04-01', 237.50, 17),
(25, '2024-07-01', '2024-08-01', 220.00, 18);

-- Auto Payments (20 records)
INSERT INTO RAH_AUTO_PAYMENT VALUES
(1, '2022-03-28', 212.50, 'Debit', 1),
(2, '2022-06-25', 212.50, 'Credit', 2),
(3, '2022-09-20', 212.50, 'Credit', 3),
(4, '2022-12-28', 212.50, 'Debit', 4),
(5, '2023-06-10', 187.50, 'PayPal', 5),
(6, '2023-09-10', 187.50, 'PayPal', 6),
(7, '2023-08-28', 182.50, 'Credit', 8),
(8, '2023-11-25', 182.50, 'Check', 9),
(9, '2023-04-28', 275.00, 'Credit', 11),
(10, '2023-07-25', 275.00, 'Debit', 12),
(11, '2024-02-10', 247.50, 'Credit', 13),
(12, '2024-02-25', 195.00, 'PayPal', 15),
(13, '2023-06-25', 300.00, 'Credit', 17),
(14, '2023-09-28', 300.00, 'Debit', 18),
(15, '2024-03-28', 162.50, 'Check', 19),
(16, '2024-04-25', 262.50, 'Credit', 20),
(17, '2024-04-20', 205.00, 'Debit', 21),
(18, '2024-06-10', 235.00, 'Credit', 22),
(19, '2024-06-25', 177.50, 'PayPal', 23),
(20, '2024-03-25', 237.50, 'Credit', 24);

-- Vehicles (20 records)
INSERT INTO RAH_VEHICLE VALUES
(1, '1HGBH41JXMN109186', 'Honda', 'Civic', 2021, 'L', 1),
(2, '2T1BURHE0JC067841', 'Toyota', 'Corolla', 2020, 'F', 1),
(3, '5YJSA1DN4DFP14736', 'Tesla', 'Model S', 2023, 'O', 2),
(4, 'WBA3A5C51CF256789', 'BMW', '328i', 2022, 'L', 3),
(5, '1FADP3F29JL234567', 'Ford', 'Focus', 2019, 'F', 4),
(6, 'WDDGF4HB1CA765432', 'Mercedes', 'C300', 2023, 'O', 5),
(7, 'JN1TBNT30Z0012345', 'Nissan', 'Altima', 2021, 'L', 6),
(8, '3VWDX7AJ0BM345678', 'Volkswagen', 'Jetta', 2020, 'F', 7),
(9, 'JTDKN3DU5A0456789', 'Toyota', 'Prius', 2022, 'L', 8),
(10, '1G1YY22G965567890', 'Chevrolet', 'Corvette', 2024, 'O', 9),
(11, 'WAUZZZ4G6BN678901', 'Audi', 'A4', 2023, 'L', 10),
(12, '5FNRL6H71HB789012', 'Honda', 'Pilot', 2021, 'F', 10),
(13, 'SALGS2SV5GA890123', 'Land Rover', 'Range Rover', 2024, 'O', 11),
(14, '4T1B11HK2JU901234', 'Toyota', 'Camry', 2022, 'L', 12),
(15, 'WBAPH5C50BA012345', 'BMW', '535i', 2021, 'F', 13),
(16, 'JM1BL1V73D1123456', 'Mazda', 'Mazda3', 2020, 'L', 14),
(17, '5YJ3E1EA8LF234567', 'Tesla', 'Model 3', 2023, 'O', 15),
(18, '1FMSK8DH4LG345678', 'Ford', 'Explorer', 2022, 'L', 16),
(19, 'WP0AA2A70CL456789', 'Porsche', '911', 2024, 'O', 17),
(20, '19XFC2F52NE567890', 'Honda', 'Accord', 2023, 'L', 18);

-- Drivers (20 records)
INSERT INTO RAH_DRIVER VALUES
(1, 'DL-NY-001234', 'James', 'Anderson', 35),
(2, 'DL-NY-005678', 'Maria', 'Anderson', 33),
(3, 'DL-NY-009012', 'Sarah', 'Martinez', 28),
(4, 'DL-NJ-001234', 'Robert', 'Johnson', 42),
(5, 'DL-NJ-005678', 'Linda', 'Johnson', 39),
(6, 'DL-PA-001234', 'Michael', 'Brown', 31),
(7, 'DL-NJ-009012', 'William', 'Garcia', 45),
(8, 'DL-CT-001234', 'Amanda', 'Miller', 26),
(9, 'DL-NJ-013456', 'Daniel', 'Wilson', 38),
(10, 'DL-NY-013456', 'Jennifer', 'Taylor', 44),
(11, 'DL-NY-017890', 'David', 'Taylor', 46),
(12, 'DL-NY-021234', 'Ashley', 'Jackson', 23),
(13, 'DL-NJ-017890', 'Matthew', 'White', 52),
(14, 'DL-CT-005678', 'Stephanie', 'Harris', 36),
(15, 'DL-RI-001234', 'Andrew', 'Clark', 29),
(16, 'DL-NJ-021234', 'Joshua', 'Robinson', 33),
(17, 'DL-MA-001234', 'Kevin', 'Young', 41),
(18, 'DL-PA-005678', 'Thomas', 'Brown', 19),
(19, 'DL-CT-009012', 'Rachel', 'King', 25),
(20, 'DL-NY-025678', 'Nicole', 'Lewis', 37);

-- Vehicle-Driver assignments (25 records)
INSERT INTO RAH_VEHICLE_DRIVER VALUES
(1, 1), (1, 2), (2, 1), (2, 2), (3, 3),
(4, 4), (4, 5), (5, 4), (6, 6), (7, 7),
(8, 7), (9, 8), (10, 9), (11, 10), (11, 11),
(12, 10), (12, 11), (13, 12), (14, 14), (15, 15),
(16, 16), (17, 17), (18, 19), (19, 16), (20, 6);

-- Users (bcrypt hash for 'password123')
-- Hash: $2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS
INSERT INTO RAH_USER (USERNAME, PASSWORD_HASH, EMAIL, ROLE, CUST_ID, SECURITY_QUESTION, SECURITY_ANSWER_HASH, FAILED_LOGIN_ATTEMPTS, ACCOUNT_LOCKED, LAST_LOGIN) VALUES
('employee1', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'employee1@niceinsurance.com', 'employee', NULL, 'What is your favorite color?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-06 10:30:00'),
('customer1', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'james.anderson@email.com', 'customer', 1, 'What is your pet name?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-05 14:20:00'),
('customer2', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'sarah.martinez@email.com', 'customer', 2, 'What city were you born in?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-04 09:15:00');

-- Login History
INSERT INTO RAH_LOGIN_HISTORY (USER_ID, LOGIN_DT, IP_ADDRESS, SUCCESS) VALUES
(1, '2026-04-06 10:30:00', '192.168.1.100', 1),
(1, '2026-04-05 08:45:00', '192.168.1.100', 1),
(2, '2026-04-05 14:20:00', '10.0.0.50', 1),
(2, '2026-04-04 11:00:00', '10.0.0.50', 0),
(2, '2026-04-04 11:01:00', '10.0.0.50', 1),
(3, '2026-04-04 09:15:00', '172.16.0.25', 1),
(3, '2026-04-03 16:30:00', '172.16.0.25', 1),
(1, '2026-04-04 09:00:00', '192.168.1.101', 1),
(1, '2026-04-03 08:30:00', '192.168.1.100', 1),
(2, '2026-04-03 10:45:00', '10.0.0.51', 1),
(3, '2026-04-02 14:00:00', '172.16.0.25', 1),
(1, '2026-04-02 07:30:00', '192.168.1.100', 0),
(1, '2026-04-02 07:31:00', '192.168.1.100', 1),
(2, '2026-04-01 09:00:00', '10.0.0.50', 1),
(3, '2026-04-01 11:30:00', '172.16.0.25', 1);

-- ============================================================
-- END OF SETUP
-- ============================================================
