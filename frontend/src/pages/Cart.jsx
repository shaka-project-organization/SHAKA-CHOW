import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { ordersApi } from '../api';
import './Cart.css';

const DELIVERY_FEE = 500;

const Cart = () => {
  const { items, restaurantId, updateQty, removeItem, clearCart, subtotal, itemCount } = useCart();
  const { user } = useAuth();
  const { addToast } = useToast();
  const navigate = useNavigate();

  const [address, setAddress] = useState({ street: '', city: 'Lagos', state: 'Lagos' });
  const [paymentMethod, setPaymentMethod] = useState('cash_on_delivery');
  const [notes, setNotes] = useState('');
  const [placing, setPlacing] = useState(false);

  const total = subtotal + DELIVERY_FEE;

  const handlePlaceOrder = async () => {
    if (!user) {
      addToast('Please log in to place an order.');
      return;
    }
    if (!address.street.trim()) {
      addToast('Please enter your delivery address.');
      return;
    }
    setPlacing(true);
    try {
      const { data } = await ordersApi.create({
        restaurantId,
        items,
        deliveryAddress: address,
        paymentMethod,
        notes,
      });
      clearCart();
      addToast('Order placed successfully! 🎉');
      navigate(`/orders/${data.data.order._id}`);
    } catch (err) {
      addToast(err.response?.data?.message || 'Could not place order. Try again.');
    } finally {
      setPlacing(false);
    }
  };

  if (items.length === 0) {
    return (
      <div className="cart-empty container">
        <div className="empty-emoji">🛒</div>
        <h2>Your cart is empty</h2>
        <p>Add some delicious dishes to get started.</p>
        <Link to="/" className="btn btn-primary">Browse menu</Link>
      </div>
    );
  }

  return (
    <main className="cart-page container">
      <h1 className="cart-title">Your cart <span>({itemCount} {itemCount === 1 ? 'item' : 'items'})</span></h1>

      <div className="cart-layout">
        {/* Items */}
        <div className="cart-items">
          {items.map((item) => (
            <div key={item.menuItemId} className="cart-item">
              <span className="cart-item-emoji">{item.emoji}</span>
              <div className="cart-item-info">
                <div className="cart-item-name">{item.name}</div>
                <div className="cart-item-price">₦{item.price.toLocaleString()} each</div>
              </div>
              <div className="cart-item-controls">
                <button className="qty-btn" onClick={() => updateQty(item.menuItemId, item.quantity - 1)} aria-label="Decrease quantity">−</button>
                <span className="qty-val">{item.quantity}</span>
                <button className="qty-btn" onClick={() => updateQty(item.menuItemId, item.quantity + 1)} aria-label="Increase quantity">+</button>
              </div>
              <div className="cart-item-total">₦{(item.price * item.quantity).toLocaleString()}</div>
              <button className="remove-btn" onClick={() => removeItem(item.menuItemId)} aria-label={`Remove ${item.name}`}>✕</button>
            </div>
          ))}

          <button className="clear-cart-btn" onClick={clearCart}>Clear cart</button>
        </div>

        {/* Summary + Checkout */}
        <div className="cart-summary">
          <div className="summary-card card">
            <h3>Order summary</h3>
            <div className="summary-rows">
              <div className="summary-row">
                <span>Subtotal</span>
                <span>₦{subtotal.toLocaleString()}</span>
              </div>
              <div className="summary-row">
                <span>Delivery fee</span>
                <span>₦{DELIVERY_FEE.toLocaleString()}</span>
              </div>
              <div className="summary-row summary-total">
                <span>Total</span>
                <span>₦{total.toLocaleString()}</span>
              </div>
            </div>

            <div className="checkout-fields">
              <label className="field-label">Delivery address *</label>
              <input
                className="input"
                placeholder="Street address"
                value={address.street}
                onChange={(e) => setAddress((p) => ({ ...p, street: e.target.value }))}
              />
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
                <input
                  className="input"
                  placeholder="City"
                  value={address.city}
                  onChange={(e) => setAddress((p) => ({ ...p, city: e.target.value }))}
                />
                <input
                  className="input"
                  placeholder="State"
                  value={address.state}
                  onChange={(e) => setAddress((p) => ({ ...p, state: e.target.value }))}
                />
              </div>

              <label className="field-label" style={{ marginTop: 14 }}>Payment method</label>
              <select
                className="input"
                value={paymentMethod}
                onChange={(e) => setPaymentMethod(e.target.value)}
              >
                <option value="cash_on_delivery">Cash on delivery</option>
                <option value="transfer">Bank transfer</option>
                <option value="card">Card</option>
              </select>

              <label className="field-label" style={{ marginTop: 14 }}>Order notes <span style={{ fontWeight: 400, color: 'var(--gray-400)' }}>(optional)</span></label>
              <textarea
                className="input"
                rows={3}
                placeholder="E.g. extra pepper, no onions…"
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                style={{ resize: 'vertical' }}
              />
            </div>

            <button
              className="btn btn-primary place-order-btn"
              onClick={handlePlaceOrder}
              disabled={placing}
            >
              {placing ? <span className="spinner spinner-sm" /> : null}
              {placing ? 'Placing order…' : `Place order · ₦${total.toLocaleString()}`}
            </button>

            {!user && (
              <p className="login-nudge">
                <Link to="/" style={{ color: 'var(--gold)' }}>Log in</Link> to place your order.
              </p>
            )}
          </div>
        </div>
      </div>
    </main>
  );
};

export default Cart;
