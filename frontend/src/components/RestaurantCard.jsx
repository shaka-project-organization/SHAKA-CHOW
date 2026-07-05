import React from 'react';
import { Link } from 'react-router-dom';
import './RestaurantCard.css';

const RestaurantCard = ({ restaurant }) => {
  const { _id, name, emoji, category, rating, reviewCount, deliveryTime, deliveryFee, isOpen, isFeatured } = restaurant;

  return (
    <Link to={`/restaurant/${_id}`} className="rest-card">
      <div className="rest-card-img">
        <span className="rest-emoji">{emoji}</span>
        {isFeatured && <span className="featured-badge badge badge-gold">Featured</span>}
        {!isOpen && <div className="closed-overlay">Closed</div>}
      </div>
      <div className="rest-card-body">
        <div className="rest-card-header">
          <h3 className="rest-name">{name}</h3>
          <span className="badge badge-gold">{category}</span>
        </div>
        <div className="rest-meta">
          <span className="stars">★</span>
          <span className="rating-val">{rating.toFixed(1)}</span>
          <span className="review-count">({reviewCount})</span>
          <span className="dot">·</span>
          <span>{deliveryTime}</span>
          <span className="dot">·</span>
          <span>₦{deliveryFee.toLocaleString()} delivery</span>
        </div>
      </div>
    </Link>
  );
};

export default RestaurantCard;
