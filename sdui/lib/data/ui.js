const express = require('express');
const router = express.Router();
const { getCustomerListUI, getCustomers, getCustomerListScreen } = require('../controllers/customerController');

// GET /api/ui/customer-list  — schema only (legacy)
router.get('/customer-list', getCustomerListUI);

// GET /api/ui/screen/customer-list  — SDUI: full UI + data
router.get('/screen/customer-list', getCustomerListScreen);

module.exports = router;
