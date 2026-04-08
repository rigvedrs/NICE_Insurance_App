/**
 * NICE Insurance - Main JavaScript Utilities
 * Common functions used across all pages
 */

// ---- Alert auto-dismiss ----
document.addEventListener('DOMContentLoaded', function() {
    // Auto-dismiss alerts after 5 seconds
    const alerts = document.querySelectorAll('.alert-dismissible');
    alerts.forEach(alert => {
        setTimeout(() => {
            const bsAlert = bootstrap.Alert.getOrCreateInstance(alert);
            if (bsAlert) bsAlert.close();
        }, 5000);
    });

    // Highlight active nav link
    const currentPath = window.location.pathname;
    document.querySelectorAll('.navbar-nav .nav-link').forEach(link => {
        if (link.getAttribute('href') === currentPath) {
            link.classList.add('active');
        }
    });

    // Also check dropdown items
    document.querySelectorAll('.dropdown-item').forEach(link => {
        if (link.getAttribute('href') === currentPath) {
            link.classList.add('active');
            const dropdown = link.closest('.nav-item.dropdown');
            if (dropdown) {
                dropdown.querySelector('.nav-link').classList.add('active');
            }
        }
    });
});

// ---- Format currency ----
function formatCurrency(amount) {
    return '$' + parseFloat(amount).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

// ---- Format number ----
function formatNumber(num) {
    return parseInt(num).toLocaleString();
}

// ---- Confirm delete ----
function confirmDelete(message) {
    return confirm(message || 'Are you sure you want to delete this record?');
}

// ---- Date formatting ----
function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
}

// ---- Debounce utility ----
function debounce(func, wait) {
    let timeout;
    return function(...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => func.apply(this, args), wait);
    };
}

// ---- Fetch with CSRF ----
function fetchWithCSRF(url, options = {}) {
    options.headers = options.headers || {};
    options.headers['X-CSRF-Token'] = CSRF_TOKEN;
    return fetch(url, options);
}

// ---- Table sorting ----
function sortTable(tableId, colIndex) {
    const table = document.getElementById(tableId);
    if (!table) return;
    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));

    const isNumeric = rows.every(r => {
        const cell = r.cells[colIndex];
        return cell && !isNaN(cell.textContent.replace(/[$,]/g, ''));
    });

    rows.sort((a, b) => {
        const aVal = a.cells[colIndex]?.textContent.trim() || '';
        const bVal = b.cells[colIndex]?.textContent.trim() || '';
        if (isNumeric) {
            return parseFloat(aVal.replace(/[$,]/g, '')) - parseFloat(bVal.replace(/[$,]/g, ''));
        }
        return aVal.localeCompare(bVal);
    });

    // Toggle sort direction
    if (table.dataset.sortCol === String(colIndex) && table.dataset.sortDir === 'asc') {
        rows.reverse();
        table.dataset.sortDir = 'desc';
    } else {
        table.dataset.sortCol = colIndex;
        table.dataset.sortDir = 'asc';
    }

    rows.forEach(row => tbody.appendChild(row));
}

// ---- Loading spinner ----
function showLoading(elementId) {
    const el = document.getElementById(elementId);
    if (el) {
        el.innerHTML = '<div class="text-center py-3"><div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div></div>';
    }
}
