import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import './AuthModal.css';

const AuthModal = ({ mode, onSwitchMode, onClose }) => {
  const { login, register } = useAuth();
  const { addToast } = useToast();

  const [form, setForm] = useState({ name: '', email: '', password: '', phone: '' });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const isLogin = mode === 'login';

  const validate = () => {
    const e = {};
    if (!isLogin && form.name.trim().length < 2) e.name = 'Name must be at least 2 characters.';
    if (!form.email.match(/^\S+@\S+\.\S+$/)) e.email = 'Enter a valid email address.';
    if (form.password.length < 8) e.password = 'Password must be at least 8 characters.';
    setErrors(e);
    return Object.keys(e).length === 0;
  };

  const handleChange = (e) => {
    setForm((p) => ({ ...p, [e.target.name]: e.target.value }));
    if (errors[e.target.name]) setErrors((p) => ({ ...p, [e.target.name]: '' }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;
    setLoading(true);
    try {
      if (isLogin) {
        const user = await login(form.email, form.password);
        addToast(`Welcome back, ${user.name.split(' ')[0]}! 👋`);
      } else {
        const user = await register(form.name, form.email, form.password, form.phone);
        addToast(`Account created! Welcome to ShakaChow, ${user.name.split(' ')[0]} 🎉`);
      }
      onClose();
    } catch (err) {
      const msg = err.response?.data?.message || 'Something went wrong. Try again.';
      addToast(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="modal-backdrop" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="modal-box" role="dialog" aria-modal="true" aria-label={isLogin ? 'Log in' : 'Create account'}>
        <button className="modal-close" onClick={onClose} aria-label="Close">✕</button>

        <div className="modal-logo">
          <div className="modal-logo-dot">S</div>
          <span>Shaka<strong>Chow</strong></span>
        </div>

        <h2 className="modal-title">{isLogin ? 'Welcome back' : 'Create account'}</h2>
        <p className="modal-sub">
          {isLogin ? 'Log in to continue ordering' : 'Join ShakaChow and start ordering'}
        </p>

        <form onSubmit={handleSubmit} noValidate>
          {!isLogin && (
            <div className="form-field">
              <label htmlFor="name">Full name</label>
              <input
                id="name" name="name" className={`input ${errors.name ? 'input-error' : ''}`}
                placeholder="Your full name"
                value={form.name} onChange={handleChange} autoFocus={!isLogin}
              />
              {errors.name && <span className="field-error">{errors.name}</span>}
            </div>
          )}

          <div className="form-field">
            <label htmlFor="email">Email address</label>
            <input
              id="email" name="email" type="email" className={`input ${errors.email ? 'input-error' : ''}`}
              placeholder="you@email.com"
              value={form.email} onChange={handleChange} autoFocus={isLogin}
            />
            {errors.email && <span className="field-error">{errors.email}</span>}
          </div>

          <div className="form-field">
            <label htmlFor="password">Password</label>
            <input
              id="password" name="password" type="password" className={`input ${errors.password ? 'input-error' : ''}`}
              placeholder="Min. 8 characters"
              value={form.password} onChange={handleChange}
            />
            {errors.password && <span className="field-error">{errors.password}</span>}
          </div>

          {!isLogin && (
            <div className="form-field">
              <label htmlFor="phone">Phone number <span className="optional">(optional)</span></label>
              <input
                id="phone" name="phone" type="tel" className="input"
                placeholder="+234 800 000 0000"
                value={form.phone} onChange={handleChange}
              />
            </div>
          )}

          <button type="submit" className="btn btn-dark modal-submit" disabled={loading}>
            {loading ? <span className="spinner spinner-sm" /> : null}
            {loading ? 'Please wait…' : isLogin ? 'Log in' : 'Create account'}
          </button>
        </form>

        <p className="modal-toggle">
          {isLogin ? "Don't have an account?" : 'Already have an account?'}{' '}
          <button className="toggle-link" onClick={() => onSwitchMode(isLogin ? 'signup' : 'login')}>
            {isLogin ? 'Sign up' : 'Log in'}
          </button>
        </p>
      </div>
    </div>
  );
};

export default AuthModal;
