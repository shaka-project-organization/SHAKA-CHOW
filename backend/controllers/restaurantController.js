const Restaurant = require('../models/Restaurant');

// GET /api/restaurants
const getRestaurants = async (req, res) => {
  try {
    const { category, featured, search, page = 1, limit = 12 } = req.query;

    const filter = {};
    if (category && category !== 'All') filter.category = category;
    if (featured === 'true') filter.isFeatured = true;
    if (search) filter.name = { $regex: search, $options: 'i' };

    const skip = (Number(page) - 1) * Number(limit);
    const [restaurants, total] = await Promise.all([
      Restaurant.find(filter).sort({ isFeatured: -1, rating: -1 }).skip(skip).limit(Number(limit)),
      Restaurant.countDocuments(filter),
    ]);

    res.json({
      success: true,
      data: { restaurants, total, page: Number(page), pages: Math.ceil(total / Number(limit)) },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/restaurants/:id
const getRestaurant = async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id);
    if (!restaurant) {
      return res.status(404).json({ success: false, message: 'Restaurant not found.' });
    }
    res.json({ success: true, data: { restaurant } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/restaurants (admin only)
const createRestaurant = async (req, res) => {
  try {
    const restaurant = await Restaurant.create(req.body);
    res.status(201).json({ success: true, data: { restaurant } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// PATCH /api/restaurants/:id (admin only)
const updateRestaurant = async (req, res) => {
  try {
    const restaurant = await Restaurant.findByIdAndUpdate(req.params.id, req.body, {
      new: true, runValidators: true,
    });
    if (!restaurant) return res.status(404).json({ success: false, message: 'Restaurant not found.' });
    res.json({ success: true, data: { restaurant } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// DELETE /api/restaurants/:id (admin only)
const deleteRestaurant = async (req, res) => {
  try {
    const restaurant = await Restaurant.findByIdAndDelete(req.params.id);
    if (!restaurant) return res.status(404).json({ success: false, message: 'Restaurant not found.' });
    res.json({ success: true, message: 'Restaurant deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = { getRestaurants, getRestaurant, createRestaurant, updateRestaurant, deleteRestaurant };
