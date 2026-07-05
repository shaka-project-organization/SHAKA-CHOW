import React, { createContext, useContext, useState, useCallback } from 'react';

const CartContext = createContext(null);

export const CartProvider = ({ children }) => {
  const [items, setItems] = useState([]);
  const [restaurantId, setRestaurantId] = useState(null);

  const addItem = useCallback((item, restId) => {
    // Enforce single-restaurant cart
    if (restaurantId && restaurantId !== restId) {
      return { conflict: true };
    }
    if (!restaurantId) setRestaurantId(restId);

    setItems((prev) => {
      const existing = prev.find((i) => i.menuItemId === item._id);
      if (existing) {
        return prev.map((i) =>
          i.menuItemId === item._id ? { ...i, quantity: i.quantity + 1 } : i
        );
      }
      return [...prev, { menuItemId: item._id, name: item.name, price: item.price, emoji: item.emoji, quantity: 1 }];
    });

    return { conflict: false };
  }, [restaurantId]);

  const removeItem = useCallback((menuItemId) => {
    setItems((prev) => {
      const next = prev.filter((i) => i.menuItemId !== menuItemId);
      if (next.length === 0) setRestaurantId(null);
      return next;
    });
  }, []);

  const updateQty = useCallback((menuItemId, qty) => {
    if (qty < 1) { removeItem(menuItemId); return; }
    setItems((prev) => prev.map((i) => i.menuItemId === menuItemId ? { ...i, quantity: qty } : i));
  }, [removeItem]);

  const clearCart = useCallback(() => {
    setItems([]);
    setRestaurantId(null);
  }, []);

  const subtotal = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const itemCount = items.reduce((sum, i) => sum + i.quantity, 0);

  return (
    <CartContext.Provider value={{ items, restaurantId, addItem, removeItem, updateQty, clearCart, subtotal, itemCount }}>
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error('useCart must be used inside CartProvider');
  return ctx;
};
