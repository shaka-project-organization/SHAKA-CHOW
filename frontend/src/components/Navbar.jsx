import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { useCart } from '../context/CartContext';
import { useToast } from '../context/ToastContext';
import AuthModal from './AuthModal';
import './Navbar.css';

const Navbar = () => {
  const { user, logout } = useAuth();
  const { itemCount } = useCart();
  const { addToast } = useToast();
  const navigate = useNavigate();
  const [authModal, setAuthModal] = useState(null); // 'login' | 'signup' | null
  const [menuOpen, setMenuOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    addToast('Logged out. See you soon! 👋');
    navigate('/');
  };

  return (
    <>
      <nav className="navbar">
        <div className="navbar-inner">
          <Link to="/" className="navbar-logo">
            <div className="logo-dot">S</div>
            <span>Shaka<strong>Chow</strong></span>
          </Link>

          <div className="navbar-links hide-mobile">
            <Link to="/#restaurants">Restaurants</Link>
            <Link to="/#menu">Menu</Link>
            {user && <Link to="/orders">My orders</Link>}
          </div>

          <div className="navbar-actions">
            <Link to="/cart" className="cart-btn" aria-label={`Cart — ${itemCount} items`}>
              <span className="cart-icon">🛒</span>
              {itemCount > 0 && <span className="cart-badge">{itemCount}</span>}
            </Link>

            {user ? (
              <div className="user-menu">
                <button className="user-btn" onClick={() => setMenuOpen((p) => !p)}>
                  <div className="avatar">{user.name[0].toUpperCase()}</div>
                  <span className="hide-mobile">{user.name.split(' ')[0]}</span>
                  <span style={{ fontSize: 10 }}>▾</span>
                </button>
                {menuOpen && (
                  <div className="dropdown">
                    <Link to="/profile" onClick={() => setMenuOpen(false)}>Profile</Link>
                    <Link to="/orders" onClick={() => setMenuOpen(false)}>My orders</Link>
                    <button onClick={handleLogout}>Log out</button>
                  </div>
                )}
              </div>
            ) : (
              <>
                <button className="btn-nav-ghost" onClick={() => setAuthModal('login')}>Log in</button>
                <button className="btn btn-primary" onClick={() => setAuthModal('signup')}>Sign up</button>
              </>
            )}
          </div>
        </div>
      </nav>

      {authModal && (
        <AuthModal
          mode={authModal}
          onSwitchMode={setAuthModal}
          onClose={() => setAuthModal(null)}
        />
      )}
    </>
  );
};

export default Navbar;
