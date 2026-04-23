const fs = require('fs');
const path = require('path');
const asyncHandler = require('../utils/asyncHandler');

// ─── Path Helpers ─────────────────────────────────────────────────────────────
const DATA_DIR = path.join(__dirname, '../data');
const CUSTOMER_DATA_PATH = path.join(DATA_DIR, 'customer_data.json');
const UI_SCHEMA_PATH = path.join(DATA_DIR, 'customer_ui_schema.json');

// ─── Data Loading ─────────────────────────────────────────────────────────────
const loadJSON = (filePath) => {
    try {
        const raw = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(raw);
    } catch (err) {
        console.error(`Error loading JSON from ${filePath}:`, err);
        return [];
    }
};

// Internal mutable state (simulating a database)
let CUSTOMERS = loadJSON(CUSTOMER_DATA_PATH);

// ─── Enrichment tables ────────────────────────────────────────────────────────
const STATUS_STYLE = {
    Active: { color: '#22C55E', textColor: '#FFFFFF' },
    Inactive: { color: '#EF4444', textColor: '#FFFFFF' },
    Pending: { color: '#F59E0B', textColor: '#FFFFFF' },
};
const AVATAR_PALETTE = ['#6366F1', '#EC4899', '#14B8A6', '#F97316', '#8B5CF6', '#3B82F6', '#10B981'];

const enrichCustomer = (customer, index) => ({
    ...customer,
    initials: customer.name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2),
    statusColor: STATUS_STYLE[customer.status]?.color ?? '#9CA3AF',
    statusTextColor: STATUS_STYLE[customer.status]?.textColor ?? '#FFFFFF',
    avatarColor: AVATAR_PALETTE[index % AVATAR_PALETTE.length],
});

// ─── Legacy: GET /ui/customer-list ────────────────────────────────────────────
const getCustomerListUI = asyncHandler(async (req, res) => {
    return res.status(200).json({
        version: 1,
        fields: [
            { key: 'name', label: 'Customer Name' },
            { key: 'phone', label: 'Phone Number' },
            { key: 'status', label: 'Status' },
        ],
    });
});

// ─── Legacy: GET /customers ───────────────────────────────────────────────────
const getCustomers = asyncHandler(async (req, res) => {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;

    const startIndex = (page - 1) * limit;
    const paginated = CUSTOMERS.slice(startIndex, startIndex + limit);
    const total = CUSTOMERS.length;

    return res.status(200).json({
        success: true,
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        data: paginated,
    });
});

// ─── SDUI: GET /screen/customer-list ─────────────────────────────────────────
const getCustomerListScreen = async (req, res) => {
    try {
        const { status: statusFilter, search } = req.query;

        // Load schema from file
        const screen = loadJSON(UI_SCHEMA_PATH);

        // --- Filter ---
        let filtered = [...CUSTOMERS];
        if (statusFilter && statusFilter !== 'all') {
            filtered = filtered.filter(c => c.status.toLowerCase() === statusFilter.toLowerCase());
        }
        if (search) {
            const q = search.toLowerCase();
            filtered = filtered.filter(c =>
                c.name.toLowerCase().includes(q) || c.phone.includes(q)
            );
        }

        // --- Enrich ---
        const data = filtered.map(enrichCustomer);

        // --- Dynamic updates to the schema based on data ---
        if (screen.appBar) {
            screen.appBar.subtitle = `${data.length} total`;
        }

        // Handle Chip selection state in schema
        const chipGroup = screen.body.children.find(c => c.type === 'chipGroup');
        if (chipGroup && chipGroup.chips) {
            chipGroup.chips = chipGroup.chips.map(chip => ({
                ...chip,
                selected: (!statusFilter || statusFilter === 'all') 
                    ? chip.value === 'all' 
                    : chip.value === statusFilter
            }));
        }

        return res.status(200).json(screen);
    } catch (error) {
        return res.status(500).json({
            success: false,
            message: error.message || 'Internal Server Error',
        });
    }
};

// GET /customers/data
const getCustomerData = asyncHandler(async (req, res) => {
    const enriched = CUSTOMERS.map(enrichCustomer);

    return res.status(200).json({
        success: true,
        data: enriched,
    });
});

// POST /customers/update-orders
const updateCustomerOrders = asyncHandler(async (req, res) => {
    const { id, orders } = req.body;

    const customer = CUSTOMERS.find(c => c.id === id);

    if (!customer) {
        return res.status(404).json({
            success: false,
            message: 'Customer not found',
        });
    }

    // Update in-memory state
    customer.orders = Math.max(0, parseInt(orders) || 0);

    return res.status(200).json({
        success: true,
        data: customer,
    });
});

module.exports = {
    getCustomerListUI,
    getCustomers,
    getCustomerListScreen,
    getCustomerData,
    updateCustomerOrders,
};
