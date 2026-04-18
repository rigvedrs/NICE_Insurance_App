/**
 * NICE Insurance - Chart.js Visualization Helpers
 * Consistent chart styling across the application
 */

// NYU brand color palette for charts
// Primary: NYU Violet (#57068c), Ultra Violet (#8900e1)
// Secondary: Deep Violet (#330662), Medium Violet 1/2 (#702b9d, #7b5aa6),
//            Light Violet 1 (#ab82c5)
// Accents:  Teal (#009b8a), Blue (#59b2d1), Magenta (#fb0f78), Yellow (#f4ec51)
const CHART_COLORS = {
    primary: '#57068c',       // NYU Violet
    secondary: '#8900e1',     // Ultra Violet
    success: '#009b8a',       // Teal
    warning: '#f4ec51',       // Yellow
    danger: '#fb0f78',        // Magenta
    info: '#59b2d1',          // Blue
    deepViolet: '#330662',
    mediumViolet1: '#702b9d',
    mediumViolet2: '#7b5aa6',
    lightViolet: '#ab82c5',
};

const CHART_PALETTE = [
    '#57068c', // NYU Violet
    '#8900e1', // Ultra Violet
    '#009b8a', // Teal
    '#59b2d1', // Blue
    '#7b5aa6', // Medium Violet 2
    '#fb0f78', // Magenta
    '#ab82c5', // Light Violet 1
    '#702b9d', // Medium Violet 1
    '#f4ec51', // Yellow
    '#330662'  // Deep Violet
];

const CHART_PALETTE_ALPHA = [
    'rgba(87,6,140,0.75)',    // NYU Violet
    'rgba(137,0,225,0.70)',   // Ultra Violet
    'rgba(0,155,138,0.75)',   // Teal
    'rgba(89,178,209,0.75)',  // Blue
    'rgba(123,90,166,0.75)',  // Medium Violet 2
    'rgba(251,15,120,0.70)',  // Magenta
    'rgba(171,130,197,0.75)', // Light Violet 1
    'rgba(112,43,157,0.75)',  // Medium Violet 1
    'rgba(244,236,81,0.75)',  // Yellow
    'rgba(51,6,98,0.80)'      // Deep Violet
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
                backgroundColor: 'rgba(87,6,140,0.12)',
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
