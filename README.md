# 🍛 ShakaChow

Nigerian and continental food ordering app — built by Shaka.

**Stack:** React · Node.js/Express · MongoDB · Docker · Kubernetes (EKS)

---

## Project structure

```
shakachow/
├── frontend/          # React app (Create React App)
│   ├── src/
│   │   ├── api/       # Axios instance + endpoint helpers
│   │   ├── components/# Navbar, RestaurantCard, MenuItemCard, AuthModal
│   │   ├── context/   # AuthContext, CartContext, ToastContext
│   │   └── pages/     # Home, RestaurantDetail, Cart, Orders, OrderDetail, Profile
│   ├── Dockerfile
│   └── nginx.conf
├── backend/           # Express API
│   ├── config/        # DB connection, JWT helpers
│   ├── controllers/   # authController, restaurantController, menuController, orderController
│   ├── middleware/    # auth (protect, restrictTo)
│   ├── models/        # User, Restaurant, MenuItem, Order
│   ├── routes/        # auth, restaurants, menu, orders
│   ├── seed.js        # Seed script — 6 restaurants + 22 menu items
│   ├── Dockerfile
│   └── server.js
└── docker-compose.yml # Local full-stack dev environment
```

---

## Local development

### Option A — Docker Compose (recommended)

```bash
# Start MongoDB + API + frontend
docker compose up --build

# In a second terminal, seed the database
docker exec shakachow-api node seed.js
```

Frontend → http://localhost:3000
API      → http://localhost:5000/api/health

---

### Option B — Run services individually

**Backend**
```bash
cd backend
cp .env.example .env          # Fill in your values
npm install
node seed.js                  # Seed restaurants and menu items
npm run dev                   # Starts on :5000
```

**Frontend**
```bash
cd frontend
npm install
npm start                     # Starts on :3000
```

> The frontend proxies `/api` to `localhost:5000` (configured in package.json).

---

## API reference

### Auth
| Method | Route              | Auth | Description            |
|--------|--------------------|------|------------------------|
| POST   | /api/auth/register | —    | Create account         |
| POST   | /api/auth/login    | —    | Login, get tokens      |
| POST   | /api/auth/refresh  | —    | Refresh access token   |
| POST   | /api/auth/logout   | ✓    | Invalidate tokens      |
| GET    | /api/auth/me       | ✓    | Get current user       |
| PATCH  | /api/auth/me       | ✓    | Update profile         |

### Restaurants
| Method | Route                   | Auth  | Description           |
|--------|-------------------------|-------|-----------------------|
| GET    | /api/restaurants        | —     | List (filter/search)  |
| GET    | /api/restaurants/:id    | —     | Single restaurant     |
| POST   | /api/restaurants        | admin | Create                |
| PATCH  | /api/restaurants/:id    | admin | Update                |
| DELETE | /api/restaurants/:id    | admin | Delete                |

### Menu
| Method | Route           | Auth  | Description           |
|--------|-----------------|-------|-----------------------|
| GET    | /api/menu       | —     | List items            |
| GET    | /api/menu/:id   | —     | Single item           |
| POST   | /api/menu       | admin | Create item           |
| PATCH  | /api/menu/:id   | admin | Update item           |
| DELETE | /api/menu/:id   | admin | Delete item           |

### Orders
| Method | Route                    | Auth  | Description           |
|--------|--------------------------|-------|-----------------------|
| POST   | /api/orders              | ✓     | Place order           |
| GET    | /api/orders              | ✓     | My orders             |
| GET    | /api/orders/:id          | ✓     | Order detail          |
| PATCH  | /api/orders/:id/cancel   | ✓     | Cancel order          |
| PATCH  | /api/orders/:id/status   | admin | Update order status   |

**Query params for GET lists:** `?category=Nigerian&featured=true&search=jollof&page=1&limit=12`

---

## Docker image build

```bash
# Backend
docker build -t shakachow-api ./backend

# Frontend
docker build -t shakachow-web ./frontend \
  --build-arg REACT_APP_API_URL=https://api.engrshakacloud.online/api
```

---

## EKS deployment (next step)

This app is designed to run on the multi-tier VPC + EKS stack:

- **Frontend** → Nginx container behind ALB, HTTPS via ACM
- **Backend** → Node.js pods in private subnets, exposed internally via ClusterIP service
- **MongoDB** → MongoDB Atlas or DocumentDB in isolated subnet
- **Ingress** → AWS ALB Ingress Controller routes `/api` → backend, `/` → frontend
- **Monitoring** → Prometheus scrapes Node.js metrics, Grafana dashboard on `grafana.engrshakacloud.online`

See the Terraform repo (to be added) for the full infrastructure definition.

---

## Environment variables (backend)

| Variable               | Description                          | Example                  |
|------------------------|--------------------------------------|--------------------------|
| PORT                   | API port                             | 5000                     |
| NODE_ENV               | Environment                          | production               |
| MONGODB_URI            | MongoDB connection string            | mongodb://...            |
| JWT_SECRET             | Access token signing key             | random 32+ char string   |
| JWT_REFRESH_SECRET     | Refresh token signing key            | random 32+ char string   |
| JWT_EXPIRES_IN         | Access token TTL                     | 15m                      |
| JWT_REFRESH_EXPIRES_IN | Refresh token TTL                    | 7d                       |
| CLIENT_URL             | Frontend origin (CORS)               | https://shakachow.com    |

---

Built with ☁️ by **Musharraf Shaka Jimoh** — Cloud & DevOps Engineer
