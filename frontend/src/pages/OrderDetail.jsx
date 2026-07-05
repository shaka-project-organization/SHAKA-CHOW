import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ordersApi } from '../api';
import { useToast } from '../context/ToastContext';
import './OrderDetail.css';

const STATUS_STEPS = ['pending', 'confirmed', 'preparing', 'out_for_delivery', 'delivered'];
const STATUS_LABELS = {
  pending:          'Order placed',
  confirmed:        'Confirmed',
  preparing:        'Kitchen is cooking',
  out_for_delivery: 'On the way',
  delivered:        'Delivered',
  cancelled:        'Cancelled',
};

const OrderDetail = () => {
  const { id } = useParams();
  const [order, setOrder] = useState(null);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState(false);
  const { addToast } = useToast();

  useEffect(() => {
    ordersApi.getOne(id)
      .then(({ data }) => setOrder(data.data.order))
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [id]);

  const handleCancel = async () => {
    setCancelling(true);
    try {
      const { data } = await ordersApi.cancel(id);
      setOrder(data.data.order);
      addToast('Order cancelled.');
    } catch (err) {
      addToast(err.response?.data?.message || 'Could not cancel this order.');
    } finally {
      setCancelling(false);
    }
  };

  if (loading) {
    return (
      <div className="container" style={{ paddingTop: '2rem' }}>
        {[...Array(3)].map((_, i) => (
          <div key={i} className="skeleton" style={{ height: 80, borderRadius: 12, marginBottom: 16 }} />
        ))}
      </div>
    );
  }

  if (!order) {
    return (
      <div className="container" style={{ padding: '4rem 1.5rem', textAlign: 'center' }}>
        <h2>Order not found</h2>
        <Link to="/orders" className="btn btn-primary" style={{ marginTop: 16 }}>My orders</Link>
      </div>
    );
  }

  const isCancelled = order.status === 'cancelled';
  const stepIdx = STATUS_STEPS.indexOf(order.status);

  return (
    <main className="order-detail-page container">
      <Link to="/orders" className="back-link-dark">← My orders</Link>
      <div className="order-detail-header">
        <div>
          <h1>Order from {order.restaurant?.name}</h1>
          <p className="order-id">#{order._id.slice(-8).toUpperCase()}</p>
        </div>
        {!isCancelled && ['pending', 'confirmed'].includes(order.status) && (
          <button className="btn-cancel" onClick={handleCancel} disabled={cancelling}>
            {cancelling ? 'Cancelling…' : 'Cancel order'}
          </button>
        )}
      </div>

      {/* Progress tracker */}
      {!isCancelled && (
        <div className="progress-card card">
          <div className="progress-steps">
            {STATUS_STEPS.map((step, i) => (
              <div key={step} className={`progress-step ${i <= stepIdx ? 'done' : ''} ${i === stepIdx ? 'active' : ''}`}>
                <div className="step-dot">{i < stepIdx ? '✓' : i + 1}</div>
                <div className="step-label">{STATUS_LABELS[step]}</div>
                {i < STATUS_STEPS.length - 1 && <div className={`step-line ${i < stepIdx ? 'done' : ''}`} />}
              </div>
            ))}
          </div>
          {order.estimatedDelivery && (
            <p className="eta">
              Estimated delivery:{' '}
              <strong>{new Date(order.estimatedDelivery).toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' })}</strong>
            </p>
          )}
        </div>
      )}

      {isCancelled && (
        <div className="cancelled-banner">Order cancelled</div>
      )}

      {/* Items */}
      <div className="order-detail-items card">
        <h3>Items ordered</h3>
        {order.items.map((item, i) => (
          <div key={i} className="detail-item">
            <span className="detail-qty">{item.quantity}×</span>
            <span className="detail-name">{item.name}</span>
            <span className="detail-price">₦{(item.price * item.quantity).toLocaleString()}</span>
          </div>
        ))}
        <div className="order-totals">
          <div className="total-row"><span>Subtotal</span><span>₦{order.subtotal.toLocaleString()}</span></div>
          <div className="total-row"><span>Delivery</span><span>₦{order.deliveryFee.toLocaleString()}</span></div>
          <div className="total-row total-final"><span>Total</span><span>₦{order.total.toLocaleString()}</span></div>
        </div>
      </div>

      {/* Delivery info */}
      <div className="order-detail-delivery card">
        <h3>Delivery details</h3>
        <p><strong>Address:</strong> {order.deliveryAddress.street}, {order.deliveryAddress.city}, {order.deliveryAddress.state}</p>
        <p><strong>Payment:</strong> {order.paymentMethod.replace(/_/g, ' ')}</p>
        {order.notes && <p><strong>Notes:</strong> {order.notes}</p>}
        <p><strong>Placed:</strong> {new Date(order.createdAt).toLocaleString('en-NG')}</p>
      </div>
    </main>
  );
};

export default OrderDetail;
