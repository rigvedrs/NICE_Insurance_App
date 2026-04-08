/**
 * NICE Insurance - Dashboard Interactions
 * Handles dynamic data loading and dashboard-specific features
 */

/**
 * Load table counts and display as badges
 */
function loadTableCounts() {
    const container = document.getElementById('tableCountsContainer');
    if (!container) return;

    fetch('/api/table-counts')
    .then(r => r.json())
    .then(data => {
        let html = '<div class="row g-2">';
        const tableNames = {
            'RAH_CUSTOMER': { icon: 'bi-people', label: 'Customers' },
            'RAH_CUST_TYPE': { icon: 'bi-tags', label: 'Customer Types' },
            'RAH_HOME_POLICY': { icon: 'bi-house', label: 'Home Policies' },
            'RAH_HOME': { icon: 'bi-house-door', label: 'Homes' },
            'RAH_HOME_INVOICE': { icon: 'bi-receipt', label: 'Home Invoices' },
            'RAH_HOME_PAYMENT': { icon: 'bi-credit-card', label: 'Home Payments' },
            'RAH_AUTO_POLICY': { icon: 'bi-car-front', label: 'Auto Policies' },
            'RAH_AUTO_INVOICE': { icon: 'bi-receipt', label: 'Auto Invoices' },
            'RAH_AUTO_PAYMENT': { icon: 'bi-credit-card', label: 'Auto Payments' },
            'RAH_VEHICLE': { icon: 'bi-truck', label: 'Vehicles' },
            'RAH_DRIVER': { icon: 'bi-person-badge', label: 'Drivers' },
            'RAH_VEHICLE_DRIVER': { icon: 'bi-link', label: 'Vehicle-Driver' },
            'RAH_USER': { icon: 'bi-person-lock', label: 'Users' },
            'RAH_LOGIN_HISTORY': { icon: 'bi-clock-history', label: 'Login History' },
            'RAH_POLICY_AUDIT': { icon: 'bi-journal-text', label: 'Audit Trail' },
            'RAH_PASSWORD_RESET': { icon: 'bi-key', label: 'Password Resets' },
        };

        Object.keys(data).forEach(table => {
            const info = tableNames[table] || { icon: 'bi-table', label: table };
            html += `
                <div class="col-md-3 col-sm-4 col-6">
                    <div class="d-flex align-items-center p-2 rounded border">
                        <i class="bi ${info.icon} me-2 text-primary"></i>
                        <div>
                            <div class="fw-bold small">${info.label}</div>
                            <div class="text-muted small">${data[table]} rows</div>
                        </div>
                    </div>
                </div>`;
        });

        html += '</div>';
        container.innerHTML = html;
    })
    .catch(err => {
        container.innerHTML = '<div class="alert alert-warning">Could not load table counts</div>';
    });
}

/**
 * Animate counter
 */
function animateCounter(elementId, targetValue, duration) {
    const el = document.getElementById(elementId);
    if (!el) return;

    const start = 0;
    const increment = targetValue / (duration / 16);
    let current = start;

    const timer = setInterval(() => {
        current += increment;
        if (current >= targetValue) {
            current = targetValue;
            clearInterval(timer);
        }
        if (targetValue >= 1000) {
            el.textContent = Math.round(current).toLocaleString();
        } else if (targetValue < 1) {
            el.textContent = current.toFixed(2);
        } else {
            el.textContent = Math.round(current);
        }
    }, 16);
}

/**
 * Refresh all dashboard data
 */
function refreshDashboard() {
    location.reload();
}
