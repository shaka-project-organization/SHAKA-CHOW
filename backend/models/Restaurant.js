const mongoose = require('mongoose');

const restaurantSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Restaurant name is required'],
      trim: true,
    },
    description: { type: String, trim: true },
    category: {
      type: String,
      enum: ['Nigerian', 'Continental', 'Grills', 'Soups', 'Drinks', 'Desserts', 'Mixed'],
      required: true,
    },
    emoji: { type: String, default: '🍽️' },
    rating: { type: Number, default: 4.5, min: 0, max: 5 },
    reviewCount: { type: Number, default: 0 },
    deliveryTime: { type: String, default: '20–35 min' },
    deliveryFee: { type: Number, default: 500 },
    minimumOrder: { type: Number, default: 1000 },
    address: { type: String },
    isOpen: { type: Boolean, default: true },
    isFeatured: { type: Boolean, default: false },
    tags: [String],
  },
  { timestamps: true }
);

restaurantSchema.index({ category: 1 });
restaurantSchema.index({ isFeatured: -1, rating: -1 });

module.exports = mongoose.model('Restaurant', restaurantSchema);
