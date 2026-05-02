-- ============================================================
-- NICE Insurance Database - CS-GY 6083 Part II
-- MySQL conversion of the updated Oracle Data Modeler DDL
-- Core schema: 10 business tables + 4 application extension tables
-- ============================================================

DROP DATABASE IF EXISTS nice_insurance;
CREATE DATABASE nice_insurance CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE nice_insurance;

-- ============================================================
-- 1. TABLE DEFINITIONS
-- ============================================================

-- Core Table 1: RAH_CUSTOMER
CREATE TABLE RAH_CUSTOMER (
    CUST_ID INT NOT NULL COMMENT 'System-generated unique customer identifier',
    CUST_TYPE CHAR(1) NOT NULL COMMENT 'A=Auto customer, H=Home customer',
    FIRST_NAME VARCHAR(50) NOT NULL COMMENT 'Customer first name (composite resolved)',
    MIDDLE_NAME VARCHAR(50) NULL COMMENT 'Customer middle name (composite resolved)',
    LAST_NAME VARCHAR(50) NOT NULL COMMENT 'Customer last name (composite attribute resolved)',
    ADDR_LINE1 VARCHAR(100) NOT NULL COMMENT 'Street address line 1 (composite attribute resolved)',
    ADDR_LINE2 VARCHAR(100) NULL COMMENT 'Street address line 2 (composite attribute resolved)',
    CITY VARCHAR(50) NOT NULL COMMENT 'City of residence',
    STATE VARCHAR(2) NOT NULL COMMENT 'US State abbreviation',
    ZIP VARCHAR(5) NOT NULL COMMENT 'ZIP code',
    GENDER CHAR(1) NULL COMMENT 'M=Male, F=Female. Customer may choose not to provide',
    MARITAL_STATUS CHAR(1) NOT NULL COMMENT 'M=Married, S=Single, W=Widow/Widower',
    CONSTRAINT RAH_CUSTOMER_PK PRIMARY KEY (CUST_ID),
    CONSTRAINT RAH_CUSTOMER_UK_ID_TYPE UNIQUE (CUST_ID, CUST_TYPE),
    CONSTRAINT RAH_CUSTOMER_CK_3 CHECK (CUST_TYPE IN ('A','H')),
    CONSTRAINT RAH_CHK_GENDER CHECK (GENDER IN ('M','F') OR GENDER IS NULL),
    CONSTRAINT RAH_CHK_MARITAL CHECK (MARITAL_STATUS IN ('M','S','W'))
);

-- Core Table 2: RAH_HOME_POLICY
CREATE TABLE RAH_HOME_POLICY (
    HPOLICY_ID INT NOT NULL COMMENT 'Unique home insurance policy identifier',
    HPOLICY_START_DT DATE NOT NULL COMMENT 'Home insurance policy start date',
    HPOLICY_END_DT DATE NOT NULL COMMENT 'Home insurance policy end date; must be after start date',
    HPREMIUM_AMT DECIMAL(12,2) NOT NULL COMMENT 'Home insurance premium amount in USD',
    HPOLICY_STATUS CHAR(1) NOT NULL COMMENT 'C=Current, E=Expired',
    CUST_ID INT NOT NULL COMMENT 'System-generated unique customer identifier',
    CUST_TYPE CHAR(1) NOT NULL DEFAULT 'H' COMMENT 'Must be H for home policies',
    CONSTRAINT RAH_HOME_POLICY_PK PRIMARY KEY (HPOLICY_ID),
    CONSTRAINT RAH_HOME_POLICY_UK UNIQUE (HPOLICY_ID),
    CONSTRAINT RAH_CHK_HPOL_DT CHECK (HPOLICY_END_DT > HPOLICY_START_DT),
    CONSTRAINT RAH_CHK_HPREM CHECK (HPREMIUM_AMT > 0),
    CONSTRAINT RAH_CHK_HPOL_ST CHECK (HPOLICY_STATUS IN ('C','E')),
    CONSTRAINT RAH_HOME_POLICY_CK_4 CHECK (CUST_TYPE = 'H'),
    CONSTRAINT RAH_CUSTOMER_FK FOREIGN KEY (CUST_ID, CUST_TYPE)
        REFERENCES RAH_CUSTOMER (CUST_ID, CUST_TYPE) ON DELETE CASCADE
);

-- Core Table 3: RAH_HOME
CREATE TABLE RAH_HOME (
    HOME_ID INT NOT NULL COMMENT 'Unique identifier for each insured home',
    HOME_PURCHASE_DT DATE NOT NULL,
    HOME_PURCHASE_VAL DECIMAL(14,2) NOT NULL COMMENT 'Purchase value of the home in USD',
    HOME_AREA_SQFT DECIMAL(10,2) NOT NULL COMMENT 'Home area in square feet',
    HOME_TYPE CHAR(1) NOT NULL COMMENT 'S=Single Family, M=Multi Family, C=Condominium, T=Town House',
    AUTO_FIRE_NOTIF TINYINT NOT NULL COMMENT '1=Auto fire notification present, 0=Not present',
    HOME_SECURITY_SYS TINYINT NOT NULL COMMENT '1=Security system installed and monitored, 0=Not',
    SWIMMING_POOL CHAR(1) NULL COMMENT 'U=Underground, O=Overground, I=Indoor, M=Multiple, NULL=No pool',
    BASEMENT TINYINT NOT NULL COMMENT '1=Has basement, 0=No basement',
    HPOLICY_ID INT NOT NULL,
    CONSTRAINT RAH_HOME_PK PRIMARY KEY (HOME_ID),
    CONSTRAINT RAH_CHK_HOMEVAL CHECK (HOME_PURCHASE_VAL > 0),
    CONSTRAINT RAH_CHK_AREA CHECK (HOME_AREA_SQFT > 0),
    CONSTRAINT RAH_CHK_HOME_TYP CHECK (HOME_TYPE IN ('S','M','C','T')),
    CONSTRAINT RAH_CHK_FIRE CHECK (AUTO_FIRE_NOTIF IN (1,0)),
    CONSTRAINT RAH_CHK_SECURITY CHECK (HOME_SECURITY_SYS IN (1,0)),
    CONSTRAINT RAH_CHK_POOL CHECK (SWIMMING_POOL IN ('U','O','I','M') OR SWIMMING_POOL IS NULL),
    CONSTRAINT RAH_CHK_BASEMENT CHECK (BASEMENT IN (1,0)),
    CONSTRAINT RAH_HOME_POLICY_FK FOREIGN KEY (HPOLICY_ID)
        REFERENCES RAH_HOME_POLICY (HPOLICY_ID) ON DELETE CASCADE
);

-- Core Table 4: RAH_HOME_INVOICE
CREATE TABLE RAH_HOME_INVOICE (
    HINVOICE_ID INT NOT NULL COMMENT 'Unique home insurance invoice identifier',
    HINVOICE_DT DATE NOT NULL COMMENT 'Date the invoice was generated',
    HINVOICE_DUE_DT DATE NOT NULL COMMENT 'Payment due date for this invoice',
    HINVOICE_AMT DECIMAL(12,2) NOT NULL COMMENT 'Invoice amount in USD',
    HPOLICY_ID INT NOT NULL,
    CONSTRAINT RAH_HOME_INVOICE_PK PRIMARY KEY (HINVOICE_ID),
    CONSTRAINT RAH_CHK_HINV_AMT CHECK (HINVOICE_AMT > 0),
    CONSTRAINT RAH_CHK_HINV_DT CHECK (HINVOICE_DUE_DT > HINVOICE_DT),
    CONSTRAINT RAH_HOME_POLICY_FKv2 FOREIGN KEY (HPOLICY_ID)
        REFERENCES RAH_HOME_POLICY (HPOLICY_ID) ON DELETE CASCADE
);

-- Core Table 5: RAH_HOME_PAYMENT
CREATE TABLE RAH_HOME_PAYMENT (
    HPAYMENT_ID INT NOT NULL COMMENT 'Unique home insurance payment identifier',
    HPAYMENT_DT DATE NOT NULL COMMENT 'Date the payment was made',
    HPAYMENT_AMT DECIMAL(12,2) NOT NULL COMMENT 'Payment amount in USD',
    HPAYMENT_METHOD VARCHAR(10) NOT NULL COMMENT 'Method of payment accepted by NICE',
    HINVOICE_ID INT NOT NULL,
    CONSTRAINT RAH_HOME_PAYMENT_PK PRIMARY KEY (HPAYMENT_ID),
    CONSTRAINT RAH_CHK_HPAY_AMT CHECK (HPAYMENT_AMT > 0),
    CONSTRAINT RAH_CHK_HPAY_MTD CHECK (HPAYMENT_METHOD IN ('PayPal','Credit','Debit','Check')),
    CONSTRAINT RAH_HOME_INVOICE_FK FOREIGN KEY (HINVOICE_ID)
        REFERENCES RAH_HOME_INVOICE (HINVOICE_ID) ON DELETE CASCADE
);

-- Core Table 6: RAH_AUTO_POLICY
CREATE TABLE RAH_AUTO_POLICY (
    APOLICY_ID INT NOT NULL COMMENT 'Unique auto insurance policy identifier',
    APOLICY_START_DT DATE NOT NULL COMMENT 'Auto insurance policy start date',
    APOLICY_END_DT DATE NOT NULL COMMENT 'Auto insurance policy end date; must be after start date',
    APREMIUM_AMT DECIMAL(12,2) NOT NULL COMMENT 'Auto insurance premium amount in USD',
    APOLICY_STATUS CHAR(1) NOT NULL COMMENT 'C=Current, E=Expired',
    CUST_ID INT NOT NULL COMMENT 'System-generated unique customer identifier',
    CUST_TYPE CHAR(1) NOT NULL DEFAULT 'A' COMMENT 'Must be A for auto policies',
    CONSTRAINT RAH_AUTO_POLICY_PK PRIMARY KEY (APOLICY_ID),
    CONSTRAINT RAH_AUTO_POLICY_UK UNIQUE (APOLICY_ID),
    CONSTRAINT RAH_CHK_APOL_DT CHECK (APOLICY_END_DT > APOLICY_START_DT),
    CONSTRAINT RAH_CHK_APREM CHECK (APREMIUM_AMT > 0),
    CONSTRAINT RAH_CHK_APOL_ST CHECK (APOLICY_STATUS IN ('C','E')),
    CONSTRAINT RAH_AUTO_POLICY_CK_4 CHECK (CUST_TYPE = 'A'),
    CONSTRAINT RAH_CUSTOMER_FKv1 FOREIGN KEY (CUST_ID, CUST_TYPE)
        REFERENCES RAH_CUSTOMER (CUST_ID, CUST_TYPE) ON DELETE CASCADE
);

-- Core Table 7: RAH_AUTO_INVOICE
CREATE TABLE RAH_AUTO_INVOICE (
    AINVOICE_ID INT NOT NULL COMMENT 'Unique auto insurance invoice identifier',
    AINVOICE_DT DATE NOT NULL COMMENT 'Date the invoice was generated',
    AINVOICE_DUE_DT DATE NOT NULL COMMENT 'Payment due date for this invoice',
    AINVOICE_AMT DECIMAL(12,2) NOT NULL COMMENT 'Invoice amount in USD',
    APOLICY_ID INT NOT NULL,
    CONSTRAINT RAH_AUTO_INVOICE_PK PRIMARY KEY (AINVOICE_ID),
    CONSTRAINT RAH_CHK_AINV_AMT CHECK (AINVOICE_AMT > 0),
    CONSTRAINT RAH_CHK_AINV_DT CHECK (AINVOICE_DUE_DT > AINVOICE_DT),
    CONSTRAINT RAH_AUTO_POLICY_FKv2 FOREIGN KEY (APOLICY_ID)
        REFERENCES RAH_AUTO_POLICY (APOLICY_ID) ON DELETE CASCADE
);

-- Core Table 8: RAH_AUTO_PAYMENT
CREATE TABLE RAH_AUTO_PAYMENT (
    APAYMENT_ID INT NOT NULL COMMENT 'Unique auto insurance payment identifier',
    APAYMENT_DT DATE NOT NULL COMMENT 'Date the payment was made',
    APAYMENT_AMT DECIMAL(12,2) NOT NULL COMMENT 'Payment amount in USD',
    APAYMENT_METHOD VARCHAR(10) NOT NULL COMMENT 'Method of payment accepted by NICE',
    AINVOICE_ID INT NOT NULL,
    CONSTRAINT RAH_AUTO_PAYMENT_PK PRIMARY KEY (APAYMENT_ID),
    CONSTRAINT RAH_CHK_APAY_AMT CHECK (APAYMENT_AMT > 0),
    CONSTRAINT RAH_CHK_APAY_MTD CHECK (APAYMENT_METHOD IN ('PayPal','Credit','Debit','Check')),
    CONSTRAINT RAH_AUTO_INVOICE_FK FOREIGN KEY (AINVOICE_ID)
        REFERENCES RAH_AUTO_INVOICE (AINVOICE_ID) ON DELETE CASCADE
);

-- Core Table 9: RAH_VEHICLE
CREATE TABLE RAH_VEHICLE (
    VEHICLE_ID INT NOT NULL COMMENT 'System-generated unique vehicle identifier',
    VEHICLE_VIN VARCHAR(17) NOT NULL COMMENT 'Vehicle Identification Number; unique per vehicle',
    VEHICLE_MAKE VARCHAR(50) NOT NULL COMMENT 'Manufacturer/make of vehicle',
    VEHICLE_MODEL VARCHAR(50) NOT NULL COMMENT 'Model of vehicle',
    VEHICLE_YEAR SMALLINT NOT NULL COMMENT 'Year of vehicle manufacture',
    VEHICLE_STATUS CHAR(1) NOT NULL COMMENT 'L=Leased, F=Financed, O=Owned',
    APOLICY_ID INT NOT NULL,
    CONSTRAINT RAH_VEHICLE_PK PRIMARY KEY (VEHICLE_ID),
    CONSTRAINT RAH_VEHICLE__UN UNIQUE (VEHICLE_VIN),
    CONSTRAINT RAH_CHK_VEH_YEAR CHECK (VEHICLE_YEAR >= 1886),
    CONSTRAINT RAH_CHK_VEH_STAT CHECK (VEHICLE_STATUS IN ('L','F','O')),
    CONSTRAINT RAH_CHK_VIN_LEN CHECK (CHAR_LENGTH(VEHICLE_VIN) = 17),
    CONSTRAINT RAH_AUTO_POLICY_FK FOREIGN KEY (APOLICY_ID)
        REFERENCES RAH_AUTO_POLICY (APOLICY_ID) ON DELETE CASCADE
);

-- Core Table 10: RAH_DRIVER
CREATE TABLE RAH_DRIVER (
    DRIVER_ID INT NOT NULL COMMENT 'System-generated unique driver identifier',
    DRIVER_LICENSE_NO VARCHAR(20) NOT NULL COMMENT 'Driver license number; unique per driver',
    DRIVER_FNAME VARCHAR(50) NOT NULL COMMENT 'Driver first name',
    DRIVER_LNAME VARCHAR(50) NOT NULL COMMENT 'Driver last name',
    DRIVER_AGE INT NOT NULL COMMENT 'Age of the driver; must be at least 16 to drive',
    VEHICLE_ID INT NOT NULL,
    CONSTRAINT RAH_DRIVER_PK PRIMARY KEY (DRIVER_ID),
    CONSTRAINT RAH_DRIVER__UN UNIQUE (DRIVER_LICENSE_NO),
    CONSTRAINT RAH_CHK_DRV_AGE CHECK (DRIVER_AGE >= 16),
    CONSTRAINT RAH_VEHICLE_FK FOREIGN KEY (VEHICLE_ID)
        REFERENCES RAH_VEHICLE (VEHICLE_ID) ON DELETE CASCADE
);

-- Application Table 11: RAH_USER
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
    CONSTRAINT RAH_USER_CUSTOMER_FK FOREIGN KEY (CUST_ID) REFERENCES RAH_CUSTOMER(CUST_ID) ON DELETE SET NULL
);

-- Application Table 12: RAH_LOGIN_HISTORY
CREATE TABLE RAH_LOGIN_HISTORY (
    LOG_ID INT AUTO_INCREMENT PRIMARY KEY,
    USER_ID INT NOT NULL,
    LOGIN_DT DATETIME NOT NULL,
    IP_ADDRESS VARCHAR(45),
    SUCCESS TINYINT NOT NULL,
    CONSTRAINT RAH_LOGIN_HISTORY_USER_FK FOREIGN KEY (USER_ID) REFERENCES RAH_USER(USER_ID) ON DELETE CASCADE
);

-- Application Table 13: RAH_POLICY_AUDIT
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

-- Application Table 14: RAH_PASSWORD_RESET
CREATE TABLE RAH_PASSWORD_RESET (
    RESET_ID INT AUTO_INCREMENT PRIMARY KEY,
    USER_ID INT NOT NULL,
    RESET_TOKEN VARCHAR(255) NOT NULL,
    EXPIRES_AT DATETIME NOT NULL,
    USED TINYINT DEFAULT 0,
    CREATED_AT DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT RAH_PASSWORD_RESET_USER_FK FOREIGN KEY (USER_ID) REFERENCES RAH_USER(USER_ID) ON DELETE CASCADE
);


-- ============================================================
-- 2. STRATEGIC INDEXES (with rationale)
-- ============================================================

-- Frequent filtering by state for reports and analytics
CREATE INDEX idx_customer_state ON RAH_CUSTOMER(STATE);

-- Frequent filtering by city for geographic analytics
CREATE INDEX idx_customer_city ON RAH_CUSTOMER(CITY);

-- Discriminator filtering for the new arc-based customer model
CREATE INDEX idx_customer_type ON RAH_CUSTOMER(CUST_TYPE);

-- Join optimization: finding all home policies for a customer
CREATE INDEX idx_home_policy_cust ON RAH_HOME_POLICY(CUST_ID, CUST_TYPE);

-- Status filtering: active vs expired policy lookups
CREATE INDEX idx_home_policy_status ON RAH_HOME_POLICY(HPOLICY_STATUS);

-- Join optimization: finding all auto policies for a customer
CREATE INDEX idx_auto_policy_cust ON RAH_AUTO_POLICY(CUST_ID, CUST_TYPE);

-- Status filtering: active vs expired auto policy lookups
CREATE INDEX idx_auto_policy_status ON RAH_AUTO_POLICY(APOLICY_STATUS);

-- Join optimization: linking invoices to home policies
CREATE INDEX idx_home_invoice_policy ON RAH_HOME_INVOICE(HPOLICY_ID);

-- Join optimization: linking invoices to auto policies
CREATE INDEX idx_auto_invoice_policy ON RAH_AUTO_INVOICE(APOLICY_ID);

-- Join optimization: finding vehicles under an auto policy
CREATE INDEX idx_vehicle_policy ON RAH_VEHICLE(APOLICY_ID);

-- Join optimization: finding drivers assigned directly to a vehicle
CREATE INDEX idx_driver_vehicle ON RAH_DRIVER(VEHICLE_ID);

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
        INSERT INTO RAH_HOME_POLICY (HPOLICY_ID, HPOLICY_START_DT, HPOLICY_END_DT, HPREMIUM_AMT, HPOLICY_STATUS, CUST_ID, CUST_TYPE)
        VALUES (v_new_id, p_new_start, p_new_end, p_new_premium, 'C', v_cust_id, 'H');
    ELSEIF p_policy_type = 'auto' THEN
        SELECT CUST_ID INTO v_cust_id FROM RAH_AUTO_POLICY WHERE APOLICY_ID = p_old_policy_id;
        UPDATE RAH_AUTO_POLICY SET APOLICY_STATUS = 'E' WHERE APOLICY_ID = p_old_policy_id;
        SELECT COALESCE(MAX(APOLICY_ID), 0) + 1 INTO v_new_id FROM RAH_AUTO_POLICY;
        INSERT INTO RAH_AUTO_POLICY (APOLICY_ID, APOLICY_START_DT, APOLICY_END_DT, APREMIUM_AMT, APOLICY_STATUS, CUST_ID, CUST_TYPE)
        VALUES (v_new_id, p_new_start, p_new_end, p_new_premium, 'C', v_cust_id, 'A');
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
    SELECT c.*
    FROM RAH_CUSTOMER c
    WHERE c.CUST_ID = p_cust_id;

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

-- Oracle arc triggers converted to MySQL SIGNAL logic.
CREATE TRIGGER ARC_FKArc_1_RAH_HOME_POLICY_BI
BEFORE INSERT ON RAH_HOME_POLICY
FOR EACH ROW
BEGIN
    IF NEW.CUST_TYPE <> 'H' OR NOT EXISTS (
        SELECT 1 FROM RAH_CUSTOMER c WHERE c.CUST_ID = NEW.CUST_ID AND c.CUST_TYPE = 'H'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Home policy customer must have CUST_TYPE H';
    END IF;
END //

CREATE TRIGGER ARC_FKArc_1_RAH_HOME_POLICY_BU
BEFORE UPDATE ON RAH_HOME_POLICY
FOR EACH ROW
BEGIN
    IF NEW.CUST_TYPE <> 'H' OR NOT EXISTS (
        SELECT 1 FROM RAH_CUSTOMER c WHERE c.CUST_ID = NEW.CUST_ID AND c.CUST_TYPE = 'H'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Home policy customer must have CUST_TYPE H';
    END IF;
END //

CREATE TRIGGER ARC_FKArc_1_RAH_AUTO_POLICY_BI
BEFORE INSERT ON RAH_AUTO_POLICY
FOR EACH ROW
BEGIN
    IF NEW.CUST_TYPE <> 'A' OR NOT EXISTS (
        SELECT 1 FROM RAH_CUSTOMER c WHERE c.CUST_ID = NEW.CUST_ID AND c.CUST_TYPE = 'A'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Auto policy customer must have CUST_TYPE A';
    END IF;
END //

CREATE TRIGGER ARC_FKArc_1_RAH_AUTO_POLICY_BU
BEFORE UPDATE ON RAH_AUTO_POLICY
FOR EACH ROW
BEGIN
    IF NEW.CUST_TYPE <> 'A' OR NOT EXISTS (
        SELECT 1 FROM RAH_CUSTOMER c WHERE c.CUST_ID = NEW.CUST_ID AND c.CUST_TYPE = 'A'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Auto policy customer must have CUST_TYPE A';
    END IF;
END //

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

-- Customers (27 records; duplicate people model separate home/auto customer roles)
INSERT INTO RAH_CUSTOMER VALUES
(1, 'H', 'James', 'Michael', 'Anderson', '142 Oak Street', 'Apt 3B', 'Brooklyn', 'NY', '11201', 'M', 'M'),
(2, 'H', 'Sarah', 'Elizabeth', 'Martinez', '89 Elm Avenue', NULL, 'Manhattan', 'NY', '10001', 'F', 'S'),
(3, 'A', 'Robert', NULL, 'Johnson', '567 Pine Road', 'Suite 200', 'Jersey City', 'NJ', '07302', 'M', 'M'),
(4, 'H', 'Emily', 'Rose', 'Williams', '234 Maple Drive', NULL, 'Stamford', 'CT', '06901', 'F', 'M'),
(5, 'A', 'Michael', 'David', 'Brown', '891 Cedar Lane', NULL, 'Philadelphia', 'PA', '19103', 'M', 'S'),
(6, 'H', 'Jessica', NULL, 'Davis', '456 Birch Street', 'Floor 2', 'Boston', 'MA', '02101', 'F', 'W'),
(7, 'A', 'William', 'Thomas', 'Garcia', '123 Spruce Ave', NULL, 'Newark', 'NJ', '07101', 'M', 'M'),
(8, 'H', 'Amanda', 'Lynn', 'Miller', '678 Walnut Blvd', NULL, 'Hartford', 'CT', '06103', 'F', 'S'),
(9, 'A', 'Daniel', NULL, 'Wilson', '345 Ash Court', 'Unit 5', 'Hoboken', 'NJ', '07030', 'M', 'S'),
(10, 'H', 'Jennifer', 'Marie', 'Taylor', '912 Poplar Way', NULL, 'White Plains', 'NY', '10601', 'F', 'M'),
(11, 'H', 'Christopher', 'James', 'Thomas', '567 Hickory Lane', NULL, 'Cambridge', 'MA', '02139', 'M', 'M'),
(12, 'A', 'Ashley', NULL, 'Jackson', '234 Dogwood Drive', 'Apt 12A', 'Queens', 'NY', '11375', 'F', 'S'),
(13, 'H', 'Matthew', 'Ryan', 'White', '891 Magnolia St', NULL, 'Trenton', 'NJ', '08608', 'M', 'W'),
(14, 'H', 'Stephanie', 'Ann', 'Harris', '456 Sycamore Rd', NULL, 'New Haven', 'CT', '06510', 'F', 'M'),
(15, 'A', 'Andrew', NULL, 'Clark', '123 Chestnut Ave', 'Suite 100', 'Providence', 'RI', '02903', 'M', 'S'),
(16, 'H', 'Nicole', 'Grace', 'Lewis', '678 Willow Lane', NULL, 'Bronx', 'NY', '10451', 'F', 'M'),
(17, 'A', 'Joshua', 'Allen', 'Robinson', '345 Redwood Ct', NULL, 'Edison', 'NJ', '08817', 'M', 'S'),
(18, 'H', 'Lauren', NULL, 'Walker', '912 Cypress Blvd', 'Apt 7C', 'Yonkers', 'NY', '10701', 'F', 'W'),
(19, 'H', 'Kevin', 'Patrick', 'Young', '567 Juniper Way', NULL, 'Worcester', 'MA', '01608', 'M', 'M'),
(20, 'A', 'Rachel', 'Anne', 'King', '234 Aspen Drive', NULL, 'Bridgeport', 'CT', '06604', 'F', 'S'),
(21, 'A', 'James', 'Michael', 'Anderson', '142 Oak Street', 'Apt 3B', 'Brooklyn', 'NY', '11201', 'M', 'M'),
(22, 'A', 'Sarah', 'Elizabeth', 'Martinez', '89 Elm Avenue', NULL, 'Manhattan', 'NY', '10001', 'F', 'S'),
(23, 'H', 'Michael', 'David', 'Brown', '891 Cedar Lane', NULL, 'Philadelphia', 'PA', '19103', 'M', 'S'),
(24, 'A', 'Amanda', 'Lynn', 'Miller', '678 Walnut Blvd', NULL, 'Hartford', 'CT', '06103', 'F', 'S'),
(25, 'A', 'Jennifer', 'Marie', 'Taylor', '912 Poplar Way', NULL, 'White Plains', 'NY', '10601', 'F', 'M'),
(26, 'A', 'Stephanie', 'Ann', 'Harris', '456 Sycamore Rd', NULL, 'New Haven', 'CT', '06510', 'F', 'M'),
(27, 'A', 'Kevin', 'Patrick', 'Young', '567 Juniper Way', NULL, 'Worcester', 'MA', '01608', 'M', 'M');

-- Home Policies (18 records)
INSERT INTO RAH_HOME_POLICY VALUES
(1, '2022-01-15', '2023-01-15', 1250.00, 'E', 1, 'H'),
(2, '2023-01-15', '2024-01-15', 1350.00, 'E', 1, 'H'),
(3, '2023-03-01', '2024-03-01', 980.00, 'E', 2, 'H'),
(4, '2024-03-01', '2025-03-01', 1050.00, 'C', 2, 'H'),
(5, '2022-06-10', '2023-06-10', 1500.00, 'E', 4, 'H'),
(6, '2023-06-10', '2024-06-10', 1620.00, 'C', 4, 'H'),
(7, '2023-09-01', '2024-09-01', 890.00, 'C', 23, 'H'),
(8, '2024-01-01', '2025-01-01', 1100.00, 'C', 6, 'H'),
(9, '2022-11-15', '2023-11-15', 1450.00, 'E', 8, 'H'),
(10, '2023-11-15', '2024-11-15', 1550.00, 'C', 8, 'H'),
(11, '2024-02-01', '2025-02-01', 2100.00, 'C', 10, 'H'),
(12, '2023-07-01', '2024-07-01', 1780.00, 'C', 11, 'H'),
(13, '2024-04-15', '2025-04-15', 920.00, 'C', 13, 'H'),
(14, '2023-08-01', '2024-08-01', 1350.00, 'C', 14, 'H'),
(15, '2024-05-01', '2025-05-01', 1680.00, 'C', 16, 'H'),
(16, '2023-12-01', '2024-12-01', 1200.00, 'C', 18, 'H'),
(17, '2024-06-01', '2025-06-01', 1890.00, 'C', 19, 'H'),
(18, '2024-01-15', '2026-01-15', 1420.00, 'C', 1, 'H');

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
(1, '2022-03-01', '2023-03-01', 850.00, 'E', 21, 'A'),
(2, '2023-03-01', '2024-03-01', 920.00, 'E', 21, 'A'),
(3, '2023-05-15', '2024-05-15', 750.00, 'C', 22, 'A'),
(4, '2022-08-01', '2023-08-01', 680.00, 'E', 3, 'A'),
(5, '2023-08-01', '2024-08-01', 730.00, 'C', 3, 'A'),
(6, '2023-04-01', '2024-04-01', 1100.00, 'C', 5, 'A'),
(7, '2024-01-15', '2025-01-15', 990.00, 'C', 7, 'A'),
(8, '2023-10-01', '2024-10-01', 860.00, 'C', 24, 'A'),
(9, '2024-02-01', '2025-02-01', 780.00, 'C', 9, 'A'),
(10, '2023-06-01', '2024-06-01', 1200.00, 'C', 25, 'A'),
(11, '2024-03-01', '2025-03-01', 650.00, 'C', 12, 'A'),
(12, '2023-11-01', '2024-11-01', 1050.00, 'C', 26, 'A'),
(13, '2024-04-01', '2025-04-01', 820.00, 'C', 15, 'A'),
(14, '2024-05-15', '2025-05-15', 940.00, 'C', 17, 'A'),
(15, '2023-07-01', '2024-07-01', 1150.00, 'C', 27, 'A'),
(16, '2024-06-01', '2025-06-01', 710.00, 'C', 20, 'A'),
(17, '2024-03-01', '2026-03-01', 950.00, 'C', 21, 'A'),
(18, '2024-07-01', '2025-07-01', 880.00, 'C', 5, 'A');

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

-- Drivers (20 records; each driver is assigned to one vehicle in the updated DDL)
INSERT INTO RAH_DRIVER VALUES
(1, 'DL-NY-001234', 'James', 'Anderson', 35, 1),
(2, 'DL-NY-005678', 'Maria', 'Anderson', 33, 1),
(3, 'DL-NY-009012', 'Sarah', 'Martinez', 28, 3),
(4, 'DL-NJ-001234', 'Robert', 'Johnson', 42, 4),
(5, 'DL-NJ-005678', 'Linda', 'Johnson', 39, 4),
(6, 'DL-PA-001234', 'Michael', 'Brown', 31, 7),
(7, 'DL-NJ-009012', 'William', 'Garcia', 45, 8),
(8, 'DL-CT-001234', 'Amanda', 'Miller', 26, 9),
(9, 'DL-NJ-013456', 'Daniel', 'Wilson', 38, 10),
(10, 'DL-NY-013456', 'Jennifer', 'Taylor', 44, 11),
(11, 'DL-NY-017890', 'David', 'Taylor', 46, 12),
(12, 'DL-NY-021234', 'Ashley', 'Jackson', 23, 13),
(13, 'DL-NJ-017890', 'Matthew', 'White', 52, 15),
(14, 'DL-CT-005678', 'Stephanie', 'Harris', 36, 14),
(15, 'DL-RI-001234', 'Andrew', 'Clark', 29, 15),
(16, 'DL-NJ-021234', 'Joshua', 'Robinson', 33, 16),
(17, 'DL-MA-001234', 'Kevin', 'Young', 41, 17),
(18, 'DL-PA-005678', 'Thomas', 'Brown', 19, 6),
(19, 'DL-CT-009012', 'Rachel', 'King', 25, 18),
(20, 'DL-NY-025678', 'Nicole', 'Lewis', 37, 20);

-- Users (bcrypt hash for 'password123')
-- Hash: $2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS
INSERT INTO RAH_USER (USERNAME, PASSWORD_HASH, EMAIL, ROLE, CUST_ID, SECURITY_QUESTION, SECURITY_ANSWER_HASH, FAILED_LOGIN_ATTEMPTS, ACCOUNT_LOCKED, LAST_LOGIN) VALUES
('employee1', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'employee1@niceinsurance.com', 'employee', NULL, 'What is your favorite color?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-06 10:30:00'),
('customer1', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'james.anderson@email.com', 'customer', 1, 'What is your pet name?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-05 14:20:00'),
('customer2', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 'sarah.martinez@email.com', 'customer', 22, 'What city were you born in?', '$2b$12$Zm6SmkLa9IUX.VA3oYXSPuWCM5zuqpDlxA8KCaexB1Kp743wgvNPS', 0, 0, '2026-04-04 09:15:00');

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
