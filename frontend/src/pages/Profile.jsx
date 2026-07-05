import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useToast } from '../context/ToastContext';
import { authApi } from '../api';
import './Profile.css';

const Profile = () => {
  const { user, logout } = useAuth();
  const { addToast } = useToast();

  const [form, setForm] = useState({
    name: user?.name || '',
    phone: user?.phone || '',
    street: user?.address?.street || '',
    city: user?.address?.city || 'Lagos',
    state: user?.address?.state || 'Lagos',
  });
  const [saving, setSaving] = useState(false);

  const handleChange = (e) => setForm((p) => ({ ...p, [e.target.name]: e.target.value }));

  const handleSave = async (e) => {
    e.preventDefault();
    setSaving(true);
    try {
      await authApi.updateMe({
        name: form.name,
        phone: form.phone,
        address: { street: form.street, city: form.city, state: form.state },
      });
      addToast('Profile updated ✓');
    } catch {
      addToast('Could not save changes. Try again.');
    } finally {
      setSaving(false);
    }
  };

  if (!user) return null;

  return (
    <main className="profile-page container">
      <h1 className="profile-title">Profile</h1>

      <div className="profile-grid">
        {/* Avatar card */}
        <div className="profile-avatar-card card">
          <div className="profile-avatar">{user.name[0].toUpperCase()}</div>
          <div className="profile-name">{user.name}</div>
          <div className="profile-email">{user.email}</div>
          <div className="badge badge-gold profile-role">{user.role}</div>
          <button className="btn btn-outline logout-btn" onClick={logout}>Log out</button>
        </div>

        {/* Edit form */}
        <div className="profile-form card">
          <h2>Edit details</h2>
          <form onSubmit={handleSave}>
            <div className="form-field">
              <label>Full name</label>
              <input name="name" className="input" value={form.name} onChange={handleChange} />
            </div>
            <div className="form-field">
              <label>Email address</label>
              <input className="input" value={user.email} disabled style={{ opacity: 0.55 }} />
            </div>
            <div className="form-field">
              <label>Phone number</label>
              <input name="phone" className="input" value={form.phone} onChange={handleChange} placeholder="+234 800 000 0000" />
            </div>
            <div className="form-field">
              <label>Delivery street</label>
              <input name="street" className="input" value={form.street} onChange={handleChange} placeholder="Street address" />
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              <div className="form-field">
                <label>City</label>
                <input name="city" className="input" value={form.city} onChange={handleChange} />
              </div>
              <div className="form-field">
                <label>State</label>
                <input name="state" className="input" value={form.state} onChange={handleChange} />
              </div>
            </div>
            <button type="submit" className="btn btn-primary save-btn" disabled={saving}>
              {saving ? <span className="spinner spinner-sm" /> : null}
              {saving ? 'Saving…' : 'Save changes'}
            </button>
          </form>
        </div>
      </div>
    </main>
  );
};

export default Profile;
