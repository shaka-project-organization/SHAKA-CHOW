const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema(
  {
    restaurant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Restaurant',
      required: true,
    },
    name: {
      type: String,
      required: [true, 'Menu item name is required'],
      trim: true,
    },
    description: { type: String, trim: true },
    category: {
      type: String,
      enum: ['Nigerian', 'Continental', 'Grills', 'Soups', 'Drinks', 'Desserts'],
      required: true,
    },
    emoji: { type: String, default: '🍽️' },
    price: {
      type: Number,
      required: [true, 'Price is required'],
      min: [0, 'Price cannot be negative'],
    },
    isAvailable: { type: Boolean, default: true },
    isFeatured: { type: Boolean, default: false },
    isSpicy: { type: Boolean, default: false },
    isVegetarian: { type: Boolean, default: false },
    prepTime: { type: String, default: '10–15 min' },
    allergens: [String],
  },
  { timestamps: true }
);

menuItemSchema.index({ restaurant: 1, category: 1 });
menuItemSchema.index({ isFeatured: -1 });

module.exports = mongoose.model('MenuItem', menuItemSchema);
