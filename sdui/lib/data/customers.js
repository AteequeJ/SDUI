const express = require('express');
const router = express.Router();
const { getCustomers, getCustomerData, updateCustomerOrders } = require('../controllers/customerController');

// GET /api/customers?page=1&limit=10
router.get('/', getCustomers);

router.get('/data', getCustomerData);
router.post('/update-orders', updateCustomerOrders);


module.exports = router;
