const MenuItem = require('../models/MenuItem');

// GET /api/menu  — optionally filter by restaurant or category
const getMenuItems = async (req, res) => {
  try {
    const { restaurant, category, featured, search, page = 1, limit = 20 } = req.query;

    const filter = { isAvailable: true };
    if (restaurant) filter.restaurant = restaurant;
    if (category && category !== 'All') filter.category = category;
    if (featured === 'true') filter.isFeatured = true;
    if (search) filter.name = { $regex: search, $options: 'i' };

    const skip = (Number(page) - 1) * Number(limit);
    const [items, total] = await Promise.all([
      MenuItem.find(filter)
        .populate('restaurant', 'name emoji deliveryTime')
        .sort({ isFeatured: -1, name: 1 })
        .skip(skip)
        .limit(Number(limit)),
      MenuItem.countDocuments(filter),
    ]);

    res.json({
      success: true,
      data: { items, total, page: Number(page), pages: Math.ceil(total / Number(limit)) },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/menu/:id
const getMenuItem = async (req, res) => {
  try {
    const item = await MenuItem.findById(req.params.id).populate('restaurant', 'name deliveryTime deliveryFee');
    if (!item) return res.status(404).json({ success: false, message: 'Menu item not found.' });
    res.json({ success: true, data: { item } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/menu (admin only)
const createMenuItem = async (req, res) => {
  try {
    const item = await MenuItem.create(req.body);
    res.status(201).json({ success: true, data: { item } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// PATCH /api/menu/:id (admin only)
const updateMenuItem = async (req, res) => {
  try {
    const item = await MenuItem.findByIdAndUpdate(req.params.id, req.body, {
      new: true, runValidators: true,
    });
    if (!item) return res.status(404).json({ success: false, message: 'Menu item not found.' });
    res.json({ success: true, data: { item } });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// DELETE /api/menu/:id (admin only)
const deleteMenuItem = async (req, res) => {
  try {
    const item = await MenuItem.findByIdAndDelete(req.params.id);
    if (!item) return res.status(404).json({ success: false, message: 'Menu item not found.' });
    res.json({ success: true, message: 'Menu item deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = { getMenuItems, getMenuItem, createMenuItem, updateMenuItem, deleteMenuItem };
