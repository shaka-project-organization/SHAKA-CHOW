const router = require('express').Router();
const { getMenuItems, getMenuItem, createMenuItem, updateMenuItem, deleteMenuItem } = require('../controllers/menuController');
const { protect, restrictTo } = require('../middleware/auth');

router.get('/', getMenuItems);
router.get('/:id', getMenuItem);
router.post('/', protect, restrictTo('admin'), createMenuItem);
router.patch('/:id', protect, restrictTo('admin'), updateMenuItem);
router.delete('/:id', protect, restrictTo('admin'), deleteMenuItem);

module.exports = router;
