const router = require('express').Router();
const { createOrder, getMyOrders, getOrder, cancelOrder, updateOrderStatus } = require('../controllers/orderController');
const { protect, restrictTo } = require('../middleware/auth');

router.use(protect); // all order routes require auth

router.post('/', createOrder);
router.get('/', getMyOrders);
router.get('/:id', getOrder);
router.patch('/:id/cancel', cancelOrder);
router.patch('/:id/status', restrictTo('admin'), updateOrderStatus);

module.exports = router;
