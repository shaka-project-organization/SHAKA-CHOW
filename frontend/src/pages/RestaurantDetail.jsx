import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { restaurantsApi, menuApi } from '../api';
import MenuItemCard from '../components/MenuItemCard';
import './RestaurantDetail.css';

const CATEGORIES = ['All', 'Nigerian', 'Grills', 'Soups', 'Continental', 'Drinks', 'Desserts'];

const RestaurantDetail = () => {
  const { id } = useParams();
  const [restaurant, setRestaurant] = useState(null);
  const [menuItems, setMenuItems] = useState([]);
  const [loadingRest, setLoadingRest] = useState(true);
  const [loadingMenu, setLoadingMenu] = useState(true);
  const [category, setCategory] = useState('All');

  useEffect(() => {
    restaurantsApi.getOne(id)
      .then(({ data }) => setRestaurant(data.data.restaurant))
      .catch(console.error)
      .finally(() => setLoadingRest(false));
  }, [id]);

  useEffect(() => {
    const params = { restaurant: id };
    if (category !== 'All') params.category = category;
    setLoadingMenu(true);
    menuApi.getAll(params)
      .then(({ data }) => setMenuItems(data.data.items))
      .catch(console.error)
      .finally(() => setLoadingMenu(false));
  }, [id, category]);

  if (loadingRest) {
    return (
      <div className="container" style={{ paddingTop: '2rem' }}>
        <div className="skeleton" style={{ height: 200, borderRadius: 12, marginBottom: 16 }} />
        <div className="skeleton" style={{ height: 40, width: 300, borderRadius: 8 }} />
      </div>
    );
  }

  if (!restaurant) {
    return (
      <div className="container" style={{ padding: '4rem 1.5rem', textAlign: 'center' }}>
        <p style={{ fontSize: 48, marginBottom: 16 }}>🍽️</p>
        <h2>Restaurant not found</h2>
        <Link to="/" className="btn btn-primary" style={{ marginTop: 16 }}>Back to home</Link>
      </div>
    );
  }

  return (
    <main>
      {/* Header */}
      <div className="rest-detail-header">
        <div className="container">
          <Link to="/" className="back-link">← Back</Link>
          <div className="rest-detail-hero">
            <div className="rest-detail-emoji">{restaurant.emoji}</div>
            <div className="rest-detail-info">
              <h1>{restaurant.name}</h1>
              <p className="rest-detail-desc">{restaurant.description}</p>
              <div className="rest-detail-meta">
                <span className="badge badge-gold">{restaurant.category}</span>
                <span className="meta-item">★ {restaurant.rating.toFixed(1)} ({restaurant.reviewCount} reviews)</span>
                <span className="meta-sep">·</span>
                <span className="meta-item">🕒 {restaurant.deliveryTime}</span>
                <span className="meta-sep">·</span>
                <span className="meta-item">🛵 ₦{restaurant.deliveryFee.toLocaleString()} delivery</span>
                {!restaurant.isOpen && <span className="badge" style={{ background: '#fee2e2', color: '#991b1b' }}>Closed</span>}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Menu */}
      <section className="section container">
        <h2 className="section-title" style={{ marginBottom: '1rem' }}>Menu</h2>
        <div className="cat-pills" style={{ marginBottom: '1.25rem' }}>
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              className={`cat-pill ${category === cat ? 'cat-pill-active' : ''}`}
              onClick={() => setCategory(cat)}
            >
              {cat}
            </button>
          ))}
        </div>

        {loadingMenu ? (
          <div className="grid-4">
            {[...Array(6)].map((_, i) => (
              <div key={i} className="skeleton" style={{ height: 200, borderRadius: 12 }} />
            ))}
          </div>
        ) : menuItems.length === 0 ? (
          <p className="empty-state">No items in this category yet.</p>
        ) : (
          <div className="grid-4">
            {menuItems.map((item) => <MenuItemCard key={item._id} item={item} />)}
          </div>
        )}
      </section>
    </main>
  );
};

export default RestaurantDetail;
