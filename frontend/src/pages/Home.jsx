import React, { useState, useEffect } from 'react';
import { restaurantsApi, menuApi } from '../api';
import RestaurantCard from '../components/RestaurantCard';
import MenuItemCard from '../components/MenuItemCard';
import shakaPhoto from '../assets/shaka.jpg';
import './Home.css';

const CATEGORIES = ['All', 'Nigerian', 'Grills', 'Soups', 'Continental', 'Drinks', 'Desserts'];

const Home = () => {
  const [restaurants, setRestaurants] = useState([]);
  const [menuItems, setMenuItems] = useState([]);
  const [loadingRest, setLoadingRest] = useState(true);
  const [loadingMenu, setLoadingMenu] = useState(true);
  const [category, setCategory] = useState('All');
  const [search, setSearch] = useState('');

  useEffect(() => {
    restaurantsApi.getAll({ featured: true, limit: 6 })
      .then(({ data }) => setRestaurants(data.data.restaurants))
      .catch(console.error)
      .finally(() => setLoadingRest(false));
  }, []);

  useEffect(() => {
    const params = { featured: true, limit: 12 };
    if (category !== 'All') params.category = category;
    if (search) params.search = search;

    setLoadingMenu(true);
    menuApi.getAll(params)
      .then(({ data }) => setMenuItems(data.data.items))
      .catch(console.error)
      .finally(() => setLoadingMenu(false));
  }, [category, search]);

  return (
    <main>
      {/* HERO */}
      <section className="hero">
        <div className="hero-content container">
          <div className="hero-left">
            <div className="hero-badge">
              <span>📍</span> Delivering across Lagos &amp; beyond
            </div>
            <h1>
              Good food,<br />
              faster than<br />
              <span className="hero-accent">you can say jollof</span>
            </h1>
            <p>
              ShakaChow connects you to the best Nigerian and continental cuisine.
              Crafted fresh, delivered fast — straight to your door.
            </p>
            <div className="hero-actions">
              <a href="#restaurants" className="btn btn-primary btn-lg">Order now</a>
              <a href="#menu" className="btn btn-outline btn-lg">See menu</a>
            </div>
            <div className="hero-stats">
              <div className="stat">
                <span className="stat-val">50+</span>
                <span className="stat-label">Restaurants</span>
              </div>
              <div className="stat">
                <span className="stat-val">25 min</span>
                <span className="stat-label">Avg delivery</span>
              </div>
              <div className="stat">
                <span className="stat-val">4.9 ★</span>
                <span className="stat-label">App rating</span>
              </div>
            </div>
          </div>

          <div className="hero-right">
            <div className="hero-float-card hero-float-top">
              <span className="float-emoji">🍛</span>
              <div>
                <div className="float-title">Jollof Rice combo</div>
                <div className="float-sub">Just ordered · 2 min ago</div>
              </div>
            </div>
            <div className="hero-photo-wrap">
              <img src={shakaPhoto} alt="Shaka — founder of ShakaChow" className="hero-photo" />
              <div className="hero-photo-tag">🍽️ Curated by Shaka</div>
            </div>
            <div className="hero-float-card hero-float-bottom">
              <span className="float-check">✓</span>
              <div>
                <div className="float-title float-title-light">Order delivered</div>
                <div className="float-sub float-sub-light">Suya + Peppered Snail</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* SEARCH */}
      <div className="search-bar-wrap">
        <div className="container">
          <div className="search-bar">
            <span className="search-icon">🔍</span>
            <input
              type="search"
              placeholder="Search restaurants, dishes, cuisines…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="search-input"
              aria-label="Search dishes and restaurants"
            />
          </div>
        </div>
      </div>

      {/* RESTAURANTS */}
      <section className="section" id="restaurants">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Popular restaurants</h2>
            <a href="/restaurants" className="btn-ghost">See all →</a>
          </div>

          {loadingRest ? (
            <div className="grid-4">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="skeleton" style={{ height: 190, borderRadius: 12 }} />
              ))}
            </div>
          ) : restaurants.length === 0 ? (
            <p className="empty-state">No restaurants yet — check back soon!</p>
          ) : (
            <div className="grid-4">
              {restaurants.map((r) => <RestaurantCard key={r._id} restaurant={r} />)}
            </div>
          )}
        </div>
      </section>

      {/* MENU */}
      <section className="section" id="menu">
        <div className="container">
          <div className="section-header">
            <h2 className="section-title">Popular dishes</h2>
          </div>

          {/* Category pills */}
          <div className="cat-pills" role="list">
            {CATEGORIES.map((cat) => (
              <button
                key={cat}
                role="listitem"
                className={`cat-pill ${category === cat ? 'cat-pill-active' : ''}`}
                onClick={() => setCategory(cat)}
              >
                {cat}
              </button>
            ))}
          </div>

          {loadingMenu ? (
            <div className="grid-4">
              {[...Array(8)].map((_, i) => (
                <div key={i} className="skeleton" style={{ height: 200, borderRadius: 12 }} />
              ))}
            </div>
          ) : menuItems.length === 0 ? (
            <p className="empty-state">No dishes found. Try a different search or category.</p>
          ) : (
            <div className="grid-4">
              {menuItems.map((item) => <MenuItemCard key={item._id} item={item} />)}
            </div>
          )}
        </div>
      </section>

      {/* PROMO BANNER */}
      <section className="promo-section container">
        <div className="promo-banner">
          <div>
            <h3>First order? Get <span className="promo-highlight">₦1,000 off</span></h3>
            <p>Use code at checkout. Valid for new users only.</p>
          </div>
          <button className="promo-code" onClick={() => navigator.clipboard?.writeText('SHAKA1000')}>
            SHAKA1000
          </button>
        </div>
      </section>
    </main>
  );
};

export default Home;
