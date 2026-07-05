import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { ordersApi } from '../api';
import './Orders.css';

const STATUS_LABELS = {
  pending:          { label: 'Pending',          color: 'badge-yellow' },
  confirmed:        { label: 'Confirmed',         color: 'badge-blue' },
  preparing:        { label: 'Preparing',         color: 'badge-blue' },
  out_for_delivery: { label: 'On the way',        color: 'badge-gold' },
  delivered:        { label: 'Delivered',         color: 'badge-green' },
  cancelled:        { label: 'Cancelled',         color: 'badge-red' },
};

const Orders = () => {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    ordersApi.getMyOrders({ limit: 20 })
      .then(({ data }) => setOrders(data.data.orders))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="orders-page container">
        <h1 className="orders-title">My orders</h1>
        {[...Array(4)].map((_, i) => (
          <div key={i} className="skeleton" style={{ height: 90, borderRadius: 12, marginBottom: 12 }} />
        ))}
      </div>
    );
  }

  if (orders.length === 0) {
    return (
      <div className="orders-empty container">
        <div style={{ fontSize: 56, marginBottom: 12 }}>🍽️</div>
        <h2>No orders yet</h2>
        <p>Your order history will appear here.</p>
        <Link to="/" className="btn btn-primary" style={{ marginTop: 16 }}>Order now</Link>
      </div>
    );
  }

  return (
    <main className="orders-page container">
      <h1 className="orders-title">My orders</h1>
      <div className="orders-list">
        {orders.map((order) => {
          const s = STATUS_LABELS[order.status] || { label: order.status, color: 'badge-gold' };
          return (
            <Link key={order._id} to={`/orders/${order._id}`} className="order-row card">
              <div className="order-row-left">
                <span className="order-rest-emoji">{order.restaurant?.emoji || '🍽️'}</span>
                <div>
                  <div className="order-rest-name">{order.restaurant?.name}</div>
                  <div className="order-meta">
                    {order.items.length} {order.items.length === 1 ? 'item' : 'items'} ·{' '}
                    ₦{order.total.toLocaleString()} ·{' '}
                    {new Date(order.createdAt).toLocaleDateString('en-NG', { day: 'numeric', month: 'short', year: 'numeric' })}
                  </div>
                </div>
              </div>
              <span className={`status-badge ${s.color}`}>{s.label}</span>
            </Link>
          );
        })}
      </div>
    </main>
  );
};

export default Orders;
