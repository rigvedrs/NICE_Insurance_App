/**
 * NICE Insurance - Chart.js Visualization Helpers
 * Consistent chart styling across the application
 */

// Color palette for charts
const CHART_COLORS = {
    primary: '#0c6e7a',
    secondary: '#1a9baa',
    success: '#27ae60',
    warning: '#f39c12',
    danger: '#e74c3c',
    info: '#3498db',
    purple: '#9b59b6',
    teal: '#1abc9c',
    orange: '#e67e22',
    pink: '#e91e8c',
};

const CHART_PALETTE = [
    '#0c6e7a', '#1a9baa', '#3498db', '#9b59b6', '#27ae60',
    '#f39c12', '#e74c3c', '#e67e22', '#1abc9c', '#34495e'
];

const CHART_PALETTE_ALPHA = [
    'rgba(12,110,122,0.7)', 'rgba(26,155,170,0.7)', 'rgba(52,152,219,0.7)',
    'rgba(155,89,182,0.7)', 'rgba(39,174,96,0.7)', 'rgba(243,156,18,0.7)',
    'rgba(231,76,60,0.7)', 'rgba(230,126,34,0.7)', 'rgba(26,188,156,0.7)',
    'rgba(52,73,94,0.7)'
];

// Default chart options
const DEFAULT_OPTIONS = {
    responsive: true,
    maintainAspectRatio: true,
    plugins: {
        legend: {
            labels: {
                font: { size: 12, family: "'Segoe UI', system-ui, sans-serif" },
                padding: 15,
                usePointStyle: true,
            }
        },
        tooltip: {
            backgroundColor: 'rgba(0,0,0,0.8)',
            titleFont: { size: 13 },
            bodyFont: { size: 12 },
            padding: 10,
            cornerRadius: 6,
        }
    }
};

/**
 * Create a bar chart
 */
function createBarChart(canvasId, labels, data, label, colors) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    return new Chart(ctx.getContext('2d'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: label || 'Value',
                data: data,
                backgroundColor: colors || CHART_PALETTE_ALPHA.slice(0, data.length),
                borderColor: colors ? colors.map(c => c) : CHART_PALETTE.slice(0, data.length),
                borderWidth: 1,
                borderRadius: 4,
            }]
        },
        options: {
            ...DEFAULT_OPTIONS,
            scales: {
                y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.05)' } },
                x: { grid: { display: false } }
            }
        }
    });
}

/**
 * Create a horizontal bar chart
 */
function createHorizontalBarChart(canvasId, labels, data, label) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    // Fix height on the parent so Chart.js fills a stable container
    const wrapper = ctx.parentElement;
    wrapper.style.position = 'relative';
    wrapper.style.height = Math.max(260, labels.length * 36) + 'px';
    return new Chart(ctx.getContext('2d'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: label || 'Value',
                data: data,
                backgroundColor: CHART_PALETTE_ALPHA.slice(0, data.length),
                borderColor: CHART_PALETTE.slice(0, data.length),
                borderWidth: 1,
                borderRadius: 4,
            }]
        },
        options: {
            ...DEFAULT_OPTIONS,
            maintainAspectRatio: false,
            indexAxis: 'y',
            scales: {
                x: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.05)' } },
                y: { grid: { display: false } }
            }
        }
    });
}

/**
 * Create a line chart
 */
function createLineChart(canvasId, labels, data, label) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    return new Chart(ctx.getContext('2d'), {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: label || 'Value',
                data: data,
                borderColor: CHART_COLORS.primary,
                backgroundColor: 'rgba(12,110,122,0.1)',
                fill: true,
                tension: 0.3,
                pointRadius: 4,
                pointHoverRadius: 6,
                pointBackgroundColor: CHART_COLORS.primary,
            }]
        },
        options: {
            ...DEFAULT_OPTIONS,
            scales: {
                y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.05)' } },
                x: {
                    grid: { display: false },
                    type: 'category',
                    ticks: {
                        maxRotation: 45,
                        minRotation: 45,
                        autoSkip: true,
                        maxTicksLimit: 14,
                    }
                }
            }
        }
    });
}

/**
 * Create a pie chart
 */
function createPieChart(canvasId, labels, data) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    return new Chart(ctx.getContext('2d'), {
        type: 'pie',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: CHART_PALETTE.slice(0, data.length),
                borderWidth: 2,
                borderColor: '#fff',
            }]
        },
        options: {
            ...DEFAULT_OPTIONS,
            plugins: {
                ...DEFAULT_OPTIONS.plugins,
                legend: {
                    ...DEFAULT_OPTIONS.plugins.legend,
                    position: 'bottom'
                }
            }
        }
    });
}

/**
 * Create a doughnut chart
 */
function createDoughnutChart(canvasId, labels, data) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    return new Chart(ctx.getContext('2d'), {
        type: 'doughnut',
        data: {
            labels: labels,
            datasets: [{
                data: data,
                backgroundColor: CHART_PALETTE.slice(0, data.length),
                borderWidth: 2,
                borderColor: '#fff',
            }]
        },
        options: {
            ...DEFAULT_OPTIONS,
            cutout: '60%',
            plugins: {
                ...DEFAULT_OPTIONS.plugins,
                legend: {
                    ...DEFAULT_OPTIONS.plugins.legend,
                    position: 'bottom'
                }
            }
        }
    });
}

/**
 * Create a multi-dataset line chart
 */
function createMultiLineChart(canvasId, labels, datasets) {
    const ctx = document.getElementById(canvasId);
    if (!ctx) return null;
    const chartDatasets = datasets.map((ds, i) => ({
        label: ds.label,
        data: ds.data,
        borderColor: CHART_PALETTE[i],
        backgroundColor: CHART_PALETTE_ALPHA[i],
        fill: false,
        tension: 0.3,
        pointRadius: 3,
    }));
    return new Chart(ctx.getContext('2d'), {
        type: 'line',
        data: { labels, datasets: chartDatasets },
        options: {
            ...DEFAULT_OPTIONS,
            scales: {
                y: { beginAtZero: true, grid: { color: 'rgba(0,0,0,0.05)' } },
                x: { grid: { display: false } }
            }
        }
    });
}
