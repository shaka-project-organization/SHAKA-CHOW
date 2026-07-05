const Order = require('../models/Order');
const MenuItem = require('../models/MenuItem');

// POST /api/orders
const createOrder = async (req, res) => {
  try {
    const { restaurantId, items, deliveryAddress, paymentMethod, notes } = req.body;

    if (!items || items.length === 0) {
      return res.status(400).json({ success: false, message: 'Order must contain at least one item.' });
    }

    // Verify items and calculate subtotal
    let subtotal = 0;
    const orderItems = [];

    for (const cartItem of items) {
      const menuItem = await MenuItem.findById(cartItem.menuItemId);
      if (!menuItem || !menuItem.isAvailable) {
        return res.status(400).json({ success: false, message: `"${cartItem.name}" is no longer available.` });
      }
      const lineTotal = menuItem.price * cartItem.quantity;
      subtotal += lineTotal;
      orderItems.push({
        menuItem: menuItem._id,
        name: menuItem.name,
        price: menuItem.price,
        quantity: cartItem.quantity,
      });
    }

    const deliveryFee = 500;
    const total = subtotal + deliveryFee;

    const estimatedDelivery = new Date(Date.now() + 30 * 60 * 1000); // 30 min from now

    const order = await Order.create({
      user: req.user._id,
      restaurant: restaurantId,
      items: orderItems,
      subtotal,
      deliveryFee,
      total,
      deliveryAddress,
      paymentMethod,
      notes,
      estimatedDelivery,
    });

    await order.populate('restaurant', 'name emoji');

    res.status(201).json({
      success: true,
      message: 'Order placed successfully.',
      data: { order },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/orders  — current user's orders
const getMyOrders = async (req, res) => {
  try {
    const { page = 1, limit = 10, status } = req.query;
    const filter = { user: req.user._id };
    if (status) filter.status = status;

    const skip = (Number(page) - 1) * Number(limit);
    const [orders, total] = await Promise.all([
      Order.find(filter)
        .populate('restaurant', 'name emoji')
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(Number(limit)),
      Order.countDocuments(filter),
    ]);

    res.json({
      success: true,
      data: { orders, total, page: Number(page), pages: Math.ceil(total / Number(limit)) },
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/orders/:id
const getOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id).populate('restaurant', 'name emoji deliveryTime');
    if (!order) return res.status(404).json({ success: false, message: 'Order not found.' });

    // Only the owner or admin can view
    if (order.user.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    res.json({ success: true, data: { order } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PATCH /api/orders/:id/cancel
const cancelOrder = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);
    if (!order) return res.status(404).json({ success: false, message: 'Order not found.' });

    if (order.user.toString() !== req.user._id.toString()) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    if (!['pending', 'confirmed'].includes(order.status)) {
      return res.status(400).json({ success: false, message: 'Order cannot be cancelled at this stage.' });
    }

    order.status = 'cancelled';
    await order.save();

    res.json({ success: true, message: 'Order cancelled.', data: { order } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PATCH /api/orders/:id/status (admin only)
const updateOrderStatus = async (req, res) => {
  const { status } = req.body;
  const validStatuses = ['confirmed', 'preparing', 'out_for_delivery', 'delivered', 'cancelled'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ success: false, message: 'Invalid status value.' });
  }

  try {
    const order = await Order.findByIdAndUpdate(req.params.id, { status }, { new: true });
    if (!order) return res.status(404).json({ success: false, message: 'Order not found.' });
    res.json({ success: true, data: { order } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = { createOrder, getMyOrders, getOrder, cancelOrder, updateOrderStatus };
