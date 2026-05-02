-- ============================================================
-- NICE Insurance - Business Analysis Queries
-- CS-GY 6083 Part II - Section B | Team RAH
-- ============================================================

USE nice_insurance;

-- ============================================================
-- Q1: Table Join with at least 3 tables
-- Business Question: Which people have both home and auto
--   customer roles in the updated discriminator model, and what
--   is their total active premium plus number of vehicles insured?
-- ============================================================

SELECT
    home_role.CUST_ID                                   AS "Home Customer ID",
    auto_role.CUST_ID                                   AS "Auto Customer ID",
    CONCAT(home_role.FIRST_NAME, ' ', home_role.LAST_NAME) AS "Customer Name",
    CONCAT(home_role.CITY, ', ', home_role.STATE)       AS "Location",
    COUNT(DISTINCT hp.HPOLICY_ID)                       AS "Active Home Policies",
    COUNT(DISTINCT ap.APOLICY_ID)                       AS "Active Auto Policies",
    COUNT(DISTINCT v.VEHICLE_ID)                        AS "Insured Vehicles",
    COALESCE(SUM(DISTINCT hp.HPREMIUM_AMT), 0)
      + COALESCE(SUM(DISTINCT ap.APREMIUM_AMT), 0)     AS "Total Active Premium ($)"
FROM RAH_CUSTOMER home_role
    JOIN RAH_CUSTOMER auto_role
      ON home_role.FIRST_NAME = auto_role.FIRST_NAME
     AND home_role.LAST_NAME = auto_role.LAST_NAME
     AND home_role.ADDR_LINE1 = auto_role.ADDR_LINE1
     AND home_role.ZIP = auto_role.ZIP
     AND home_role.CUST_TYPE = 'H'
     AND auto_role.CUST_TYPE = 'A'
    JOIN RAH_HOME_POLICY hp ON home_role.CUST_ID = hp.CUST_ID AND hp.HPOLICY_STATUS = 'C'
    JOIN RAH_AUTO_POLICY ap ON auto_role.CUST_ID = ap.CUST_ID AND ap.APOLICY_STATUS = 'C'
    LEFT JOIN RAH_VEHICLE v ON ap.APOLICY_ID = v.APOLICY_ID
GROUP BY home_role.CUST_ID, auto_role.CUST_ID, home_role.FIRST_NAME, home_role.LAST_NAME, home_role.CITY, home_role.STATE
ORDER BY "Total Active Premium ($)" DESC;


-- ============================================================
-- Q2: Multi-row Subquery
-- Business Question: Which customers have at least one
--   unpaid or partially paid home invoice (i.e., the total
--   payments against their invoices are less than the
--   invoiced amount)?
-- ============================================================

SELECT
    c.CUST_ID                                           AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    c.CITY                                              AS "City",
    c.STATE                                             AS "State"
FROM RAH_CUSTOMER c
WHERE c.CUST_ID IN (
    SELECT hp.CUST_ID
    FROM RAH_HOME_POLICY hp
        JOIN RAH_HOME_INVOICE hi ON hp.HPOLICY_ID = hi.HPOLICY_ID
    WHERE hi.HINVOICE_ID IN (
        SELECT hi2.HINVOICE_ID
        FROM RAH_HOME_INVOICE hi2
        WHERE hi2.HINVOICE_AMT > (
            SELECT COALESCE(SUM(hpay.HPAYMENT_AMT), 0)
            FROM RAH_HOME_PAYMENT hpay
            WHERE hpay.HINVOICE_ID = hi2.HINVOICE_ID
        )
    )
)
ORDER BY c.LAST_NAME, c.FIRST_NAME;


-- ============================================================
-- Q3: Correlated Subquery
-- Business Question: For each customer, what is their most
--   recent payment date and amount across both home and auto
--   policies? Show customers who have made at least one payment.
-- ============================================================

SELECT
    c.CUST_ID                                           AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    (SELECT MAX(latest_dt)
     FROM (
         SELECT MAX(hpay.HPAYMENT_DT) AS latest_dt
         FROM RAH_HOME_PAYMENT hpay
             JOIN RAH_HOME_INVOICE hi ON hpay.HINVOICE_ID = hi.HINVOICE_ID
             JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
         WHERE hp.CUST_ID = c.CUST_ID
         UNION ALL
         SELECT MAX(apay.APAYMENT_DT) AS latest_dt
         FROM RAH_AUTO_PAYMENT apay
             JOIN RAH_AUTO_INVOICE ai ON apay.AINVOICE_ID = ai.AINVOICE_ID
             JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
         WHERE ap.CUST_ID = c.CUST_ID
     ) AS combined_dates
    )                                                    AS "Most Recent Payment Date",
    (SELECT SUM(total_paid)
     FROM (
         SELECT COALESCE(SUM(hpay.HPAYMENT_AMT), 0) AS total_paid
         FROM RAH_HOME_PAYMENT hpay
             JOIN RAH_HOME_INVOICE hi ON hpay.HINVOICE_ID = hi.HINVOICE_ID
             JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
         WHERE hp.CUST_ID = c.CUST_ID
         UNION ALL
         SELECT COALESCE(SUM(apay.APAYMENT_AMT), 0) AS total_paid
         FROM RAH_AUTO_PAYMENT apay
             JOIN RAH_AUTO_INVOICE ai ON apay.AINVOICE_ID = ai.AINVOICE_ID
             JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
         WHERE ap.CUST_ID = c.CUST_ID
     ) AS combined_payments
    )                                                    AS "Total Amount Paid ($)"
FROM RAH_CUSTOMER c
WHERE EXISTS (
    SELECT 1 FROM RAH_HOME_PAYMENT hpay
        JOIN RAH_HOME_INVOICE hi ON hpay.HINVOICE_ID = hi.HINVOICE_ID
        JOIN RAH_HOME_POLICY hp ON hi.HPOLICY_ID = hp.HPOLICY_ID
    WHERE hp.CUST_ID = c.CUST_ID
) OR EXISTS (
    SELECT 1 FROM RAH_AUTO_PAYMENT apay
        JOIN RAH_AUTO_INVOICE ai ON apay.AINVOICE_ID = ai.AINVOICE_ID
        JOIN RAH_AUTO_POLICY ap ON ai.APOLICY_ID = ap.APOLICY_ID
    WHERE ap.CUST_ID = c.CUST_ID
)
ORDER BY "Total Amount Paid ($)" DESC;


-- ============================================================
-- Q4: SET Operator Query (UNION)
-- Business Question: List all insurance policies (home and auto)
--   across the entire system with uniform columns, showing
--   policy type, customer, dates, premium, and status to
--   give a unified view for management reporting.
-- ============================================================

SELECT
    'Home'                                              AS "Policy Type",
    hp.HPOLICY_ID                                       AS "Policy ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    hp.HPOLICY_START_DT                                 AS "Start Date",
    hp.HPOLICY_END_DT                                   AS "End Date",
    hp.HPREMIUM_AMT                                     AS "Premium ($)",
    CASE hp.HPOLICY_STATUS
        WHEN 'C' THEN 'Current'
        WHEN 'E' THEN 'Expired'
    END                                                 AS "Status"
FROM RAH_HOME_POLICY hp
    JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID

UNION ALL

SELECT
    'Auto'                                              AS "Policy Type",
    ap.APOLICY_ID                                       AS "Policy ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    ap.APOLICY_START_DT                                 AS "Start Date",
    ap.APOLICY_END_DT                                   AS "End Date",
    ap.APREMIUM_AMT                                     AS "Premium ($)",
    CASE ap.APOLICY_STATUS
        WHEN 'C' THEN 'Current'
        WHEN 'E' THEN 'Expired'
    END                                                 AS "Status"
FROM RAH_AUTO_POLICY ap
    JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID

ORDER BY "Policy Type", "Status" DESC, "Premium ($)" DESC;


-- ============================================================
-- Q5: Inline View / WITH clause (CTE)
-- Business Question: For each US state, what is the average
--   premium, total number of policies, and the ratio of
--   current vs expired policies? This helps identify which
--   geographic regions generate the most insurance business.
-- ============================================================

WITH state_home AS (
    SELECT
        c.STATE,
        COUNT(*)                                         AS policy_count,
        SUM(hp.HPREMIUM_AMT)                             AS total_premium,
        SUM(CASE WHEN hp.HPOLICY_STATUS = 'C' THEN 1 ELSE 0 END) AS current_count,
        SUM(CASE WHEN hp.HPOLICY_STATUS = 'E' THEN 1 ELSE 0 END) AS expired_count
    FROM RAH_HOME_POLICY hp
        JOIN RAH_CUSTOMER c ON hp.CUST_ID = c.CUST_ID
    GROUP BY c.STATE
),
state_auto AS (
    SELECT
        c.STATE,
        COUNT(*)                                         AS policy_count,
        SUM(ap.APREMIUM_AMT)                             AS total_premium,
        SUM(CASE WHEN ap.APOLICY_STATUS = 'C' THEN 1 ELSE 0 END) AS current_count,
        SUM(CASE WHEN ap.APOLICY_STATUS = 'E' THEN 1 ELSE 0 END) AS expired_count
    FROM RAH_AUTO_POLICY ap
        JOIN RAH_CUSTOMER c ON ap.CUST_ID = c.CUST_ID
    GROUP BY c.STATE
),
combined AS (
    SELECT
        COALESCE(sh.STATE, sa.STATE)                     AS state_code,
        COALESCE(sh.policy_count, 0)
            + COALESCE(sa.policy_count, 0)               AS total_policies,
        COALESCE(sh.total_premium, 0)
            + COALESCE(sa.total_premium, 0)              AS total_premium,
        COALESCE(sh.current_count, 0)
            + COALESCE(sa.current_count, 0)              AS current_policies,
        COALESCE(sh.expired_count, 0)
            + COALESCE(sa.expired_count, 0)              AS expired_policies
    FROM state_home sh
        LEFT JOIN state_auto sa ON sh.STATE = sa.STATE
    UNION
    SELECT
        sa.STATE,
        COALESCE(sh.policy_count, 0) + sa.policy_count,
        COALESCE(sh.total_premium, 0) + sa.total_premium,
        COALESCE(sh.current_count, 0) + sa.current_count,
        COALESCE(sh.expired_count, 0) + sa.expired_count
    FROM state_auto sa
        LEFT JOIN state_home sh ON sa.STATE = sh.STATE
    WHERE sh.STATE IS NULL
)
SELECT
    state_code                                           AS "State",
    total_policies                                       AS "Total Policies",
    ROUND(total_premium, 2)                              AS "Total Premium ($)",
    ROUND(total_premium / total_policies, 2)             AS "Avg Premium ($)",
    current_policies                                     AS "Current Policies",
    expired_policies                                     AS "Expired Policies",
    ROUND(current_policies * 100.0 / total_policies, 1)  AS "Current Rate (%)"
FROM combined
ORDER BY total_premium DESC;


-- ============================================================
-- Q6: TOP-N / BOTTOM-N Query
-- Business Question: Who are the top 5 highest-value customers
--   based on total premiums (home + auto combined), and who
--   are the bottom 5? This helps identify VIP customers for
--   retention programs and at-risk low-value accounts.
-- ============================================================

-- TOP 5 Customers by Total Premium
(
SELECT
    'Top 5'                                             AS "Category",
    c.CUST_ID                                           AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    CONCAT(c.CITY, ', ', c.STATE)                       AS "Location",
    COALESCE(home_premiums.total, 0)                    AS "Home Premium ($)",
    COALESCE(auto_premiums.total, 0)                    AS "Auto Premium ($)",
    COALESCE(home_premiums.total, 0)
        + COALESCE(auto_premiums.total, 0)              AS "Combined Premium ($)"
FROM RAH_CUSTOMER c
    LEFT JOIN (
        SELECT CUST_ID, SUM(HPREMIUM_AMT) AS total
        FROM RAH_HOME_POLICY
        GROUP BY CUST_ID
    ) home_premiums ON c.CUST_ID = home_premiums.CUST_ID
    LEFT JOIN (
        SELECT CUST_ID, SUM(APREMIUM_AMT) AS total
        FROM RAH_AUTO_POLICY
        GROUP BY CUST_ID
    ) auto_premiums ON c.CUST_ID = auto_premiums.CUST_ID
ORDER BY "Combined Premium ($)" DESC
LIMIT 5
)

UNION ALL

-- BOTTOM 5 Customers by Total Premium
(
SELECT
    'Bottom 5'                                          AS "Category",
    c.CUST_ID                                           AS "Customer ID",
    CONCAT(c.FIRST_NAME, ' ', c.LAST_NAME)             AS "Customer Name",
    CONCAT(c.CITY, ', ', c.STATE)                       AS "Location",
    COALESCE(home_premiums.total, 0)                    AS "Home Premium ($)",
    COALESCE(auto_premiums.total, 0)                    AS "Auto Premium ($)",
    COALESCE(home_premiums.total, 0)
        + COALESCE(auto_premiums.total, 0)              AS "Combined Premium ($)"
FROM RAH_CUSTOMER c
    LEFT JOIN (
        SELECT CUST_ID, SUM(HPREMIUM_AMT) AS total
        FROM RAH_HOME_POLICY
        GROUP BY CUST_ID
    ) home_premiums ON c.CUST_ID = home_premiums.CUST_ID
    LEFT JOIN (
        SELECT CUST_ID, SUM(APREMIUM_AMT) AS total
        FROM RAH_AUTO_POLICY
        GROUP BY CUST_ID
    ) auto_premiums ON c.CUST_ID = auto_premiums.CUST_ID
ORDER BY "Combined Premium ($)" ASC
LIMIT 5
);

-- ============================================================
-- END OF BUSINESS QUERIES
-- ============================================================
