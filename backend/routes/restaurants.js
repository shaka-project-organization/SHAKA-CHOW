const router = require('express').Router();
const { getRestaurants, getRestaurant, createRestaurant, updateRestaurant, deleteRestaurant } = require('../controllers/restaurantController');
const { protect, restrictTo } = require('../middleware/auth');

router.get('/', getRestaurants);
router.get('/:id', getRestaurant);
router.post('/', protect, restrictTo('admin'), createRestaurant);
router.patch('/:id', protect, restrictTo('admin'), updateRestaurant);
router.delete('/:id', protect, restrictTo('admin'), deleteRestaurant);

module.exports = router;
