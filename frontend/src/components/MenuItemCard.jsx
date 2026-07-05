import React from 'react';
import { useCart } from '../context/CartContext';
import { useToast } from '../context/ToastContext';
import './MenuItemCard.css';

const MenuItemCard = ({ item }) => {
  const { addItem } = useCart();
  const { addToast } = useToast();

  const handleAdd = () => {
    const result = addItem(item, item.restaurant?._id || item.restaurant);
    if (result?.conflict) {
      addToast('Clear your cart first — it contains items from another restaurant.');
      return;
    }
    addToast(`${item.name} added to cart 🛒`);
  };

  return (
    <div className="menu-card">
      <div className="menu-card-top">
        <span className="menu-emoji">{item.emoji}</span>
        <div className="menu-badges">
          {item.isSpicy && <span className="badge badge-gold">🌶 Spicy</span>}
          {item.isVegetarian && <span className="badge badge-green">🌿 Veg</span>}
          {item.isFeatured && <span className="badge badge-navy">Popular</span>}
        </div>
      </div>
      <h4 className="menu-item-name">{item.name}</h4>
      <p className="menu-item-desc">{item.description}</p>
      <div className="menu-item-footer">
        <span className="menu-price">₦{item.price.toLocaleString()}</span>
        <button className="add-to-cart-btn" onClick={handleAdd} aria-label={`Add ${item.name} to cart`}>
          +
        </button>
      </div>
    </div>
  );
};

export default MenuItemCard;
