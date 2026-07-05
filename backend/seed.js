require('dotenv').config();
const mongoose = require('mongoose');
const connectDB = require('./config/db');
const Restaurant = require('./models/Restaurant');
const MenuItem = require('./models/MenuItem');
const User = require('./models/User');

const restaurants = [
  {
    name: "Mama Titi's Kitchen",
    description: 'Home-style Nigerian cooking made with love. Every plate tastes like Grandma made it.',
    category: 'Nigerian',
    emoji: '🏠',
    rating: 4.8,
    reviewCount: 312,
    deliveryTime: '20–35 min',
    deliveryFee: 500,
    minimumOrder: 1500,
    isOpen: true,
    isFeatured: true,
    tags: ['jollof', 'egusi', 'pounded yam', 'nigerian'],
  },
  {
    name: 'SuYa Spot',
    description: 'Northern Nigeria's finest grills, charcoal-kissed and spiced to perfection.',
    category: 'Grills',
    emoji: '🔥',
    rating: 4.9,
    reviewCount: 489,
    deliveryTime: '15–25 min',
    deliveryFee: 400,
    minimumOrder: 1000,
    isOpen: true,
    isFeatured: true,
    tags: ['suya', 'kilishi', 'asun', 'grills'],
  },
  {
    name: 'CloudBurger',
    description: 'Premium smash burgers, loaded fries, and continental bites for days.',
    category: 'Continental',
    emoji: '🍔',
    rating: 4.7,
    reviewCount: 228,
    deliveryTime: '25–40 min',
    deliveryFee: 600,
    minimumOrder: 2000,
    isOpen: true,
    isFeatured: false,
    tags: ['burgers', 'fries', 'shawarma', 'continental'],
  },
  {
    name: 'Pepper Dem Soups',
    description: 'Rich, deep, slow-cooked soups. The real Lagos experience in every bowl.',
    category: 'Soups',
    emoji: '🍲',
    rating: 4.6,
    reviewCount: 176,
    deliveryTime: '30–45 min',
    deliveryFee: 500,
    minimumOrder: 1800,
    isOpen: true,
    isFeatured: false,
    tags: ['egusi', 'bitterleaf', 'ofe akwu', 'soups'],
  },
  {
    name: 'Lagoon Seafood Bar',
    description: 'Fresh catch from the Lagos lagoon. Peppersoup, grilled fish, and more.',
    category: 'Nigerian',
    emoji: '🐟',
    rating: 4.7,
    reviewCount: 143,
    deliveryTime: '30–45 min',
    deliveryFee: 700,
    minimumOrder: 2500,
    isOpen: true,
    isFeatured: true,
    tags: ['fish', 'seafood', 'peppersoup', 'catfish'],
  },
  {
    name: 'Sweet Lagos Desserts',
    description: 'Chin chin, puff puff, cakes, and cold treats to round off any meal.',
    category: 'Desserts',
    emoji: '🍰',
    rating: 4.5,
    reviewCount: 94,
    deliveryTime: '20–30 min',
    deliveryFee: 350,
    minimumOrder: 800,
    isOpen: true,
    isFeatured: false,
    tags: ['chin chin', 'puff puff', 'cake', 'desserts'],
  },
];

const menuItemsData = [
  // Mama Titi's Kitchen — index 0
  { rIdx: 0, name: 'Jollof Rice + Chicken', description: 'Party-style smoky jollof with perfectly grilled chicken leg quarter', category: 'Nigerian', emoji: '🍛', price: 2800, isFeatured: true },
  { rIdx: 0, name: 'Pounded Yam & Egusi Soup', description: 'Smooth pounded yam with rich egusi, assorted meat, and stockfish', category: 'Soups', emoji: '🥣', price: 3200, isFeatured: true },
  { rIdx: 0, name: 'Fried Rice + Turkey', description: 'Golden party fried rice with seasoned grilled turkey thigh', category: 'Nigerian', emoji: '🍚', price: 3000, isFeatured: false },
  { rIdx: 0, name: 'Moi Moi (3 pieces)', description: 'Steamed bean pudding with egg, fish, and crayfish wrapped in leaves', category: 'Nigerian', emoji: '🟤', price: 1200, isFeatured: false },

  // SuYa Spot — index 1
  { rIdx: 1, name: 'Suya Platter (Beef)', description: 'Spiced beef suya skewers with sliced onions, tomatoes, and yaji', category: 'Grills', emoji: '🍢', price: 2500, isFeatured: true },
  { rIdx: 1, name: 'Asun (Peppered Goat)', description: 'Smoky grilled goat chopped and tossed in peppered sauce', category: 'Grills', emoji: '🐐', price: 3800, isFeatured: true },
  { rIdx: 1, name: 'Suya Wrap', description: 'Suya strips folded into a warm flatbread with fresh veg and sauce', category: 'Grills', emoji: '🌮', price: 2200, isFeatured: false },
  { rIdx: 1, name: 'Peppered Snail', description: 'Giant snails in rich red pepper sauce — a true Lagos classic', category: 'Nigerian', emoji: '🐌', price: 4500, isFeatured: true },

  // CloudBurger — index 2
  { rIdx: 2, name: 'Beef Smash Burger (Double)', description: 'Double smash patties, aged cheddar, caramelised onions, special sauce', category: 'Continental', emoji: '🍔', price: 3500, isFeatured: true },
  { rIdx: 2, name: 'Shawarma Deluxe', description: 'Loaded chicken shawarma with garlic sauce, pickles, and chips inside', category: 'Continental', emoji: '🌯', price: 2200, isFeatured: true },
  { rIdx: 2, name: 'Loaded Fries', description: 'Crispy fries with cheese sauce, jalapeños, and your choice of protein', category: 'Continental', emoji: '🍟', price: 1800, isFeatured: false },
  { rIdx: 2, name: 'Chicken Burger', description: 'Crispy fried chicken fillet, coleslaw, mayo on a toasted brioche bun', category: 'Continental', emoji: '🍗', price: 2800, isFeatured: false },

  // Pepper Dem Soups — index 3
  { rIdx: 3, name: 'Ofe Onugbu (Bitterleaf)', description: 'Classic Igbo bitter leaf soup with ofe akwu, assorted, and cocoyam', category: 'Soups', emoji: '🍵', price: 3000, isFeatured: true },
  { rIdx: 3, name: 'Oha Soup', description: 'Tender oha leaves in rich palm oil broth with assorted meat', category: 'Soups', emoji: '🫕', price: 3200, isFeatured: false },
  { rIdx: 3, name: 'Edikaikong', description: 'Calabar-style vegetable soup, heavy on the greens and protein', category: 'Soups', emoji: '🥬', price: 3500, isFeatured: true },

  // Lagoon Seafood Bar — index 4
  { rIdx: 4, name: 'Catfish Peppersoup', description: 'Hot, spicy catfish peppersoup with uda and utazi — deeply warming', category: 'Nigerian', emoji: '🐠', price: 3500, isFeatured: true },
  { rIdx: 4, name: 'Grilled Tilapia + Chips', description: 'Whole tilapia grilled to perfection with crispy chips and pepper sauce', category: 'Grills', emoji: '🐟', price: 4200, isFeatured: true },
  { rIdx: 4, name: 'Pepper Prawn Skewers', description: 'Jumbo prawns marinated in suya spice and charcoal grilled', category: 'Grills', emoji: '🦐', price: 5500, isFeatured: false },

  // Sweet Lagos Desserts — index 5
  { rIdx: 5, name: 'Puff Puff (10 pieces)', description: 'Soft, fluffy deep-fried Nigerian dough balls — the streets miss you', category: 'Desserts', emoji: '🟡', price: 800, isFeatured: true },
  { rIdx: 5, name: 'Chin Chin (250g)', description: 'Crunchy fried dough snack, lightly sweetened. The childhood one.', category: 'Desserts', emoji: '🟠', price: 1000, isFeatured: false },
  { rIdx: 5, name: 'Chapman Cooler', description: 'Classic Nigerian party drink — Fanta, Ribena, Grenadine, cucumber, chilled', category: 'Drinks', emoji: '🥤', price: 800, isFeatured: true },
  { rIdx: 5, name: 'Zobo Drink (500ml)', description: 'Hibiscus flower drink infused with ginger and citrus. Cold-pressed.', category: 'Drinks', emoji: '🍹', price: 600, isFeatured: false },
];

const seed = async () => {
  await connectDB();

  console.log('🗑️  Clearing existing data...');
  await Promise.all([
    Restaurant.deleteMany({}),
    MenuItem.deleteMany({}),
  ]);

  console.log('🏪 Seeding restaurants...');
  const createdRestaurants = await Restaurant.insertMany(restaurants);

  console.log('🍽️  Seeding menu items...');
  const menuItems = menuItemsData.map((item) => ({
    restaurant: createdRestaurants[item.rIdx]._id,
    name: item.name,
    description: item.description,
    category: item.category,
    emoji: item.emoji,
    price: item.price,
    isFeatured: item.isFeatured,
    isAvailable: true,
  }));
  await MenuItem.insertMany(menuItems);

  console.log(`\n✅ Seed complete!`);
  console.log(`   ${createdRestaurants.length} restaurants`);
  console.log(`   ${menuItems.length} menu items\n`);

  mongoose.connection.close();
};

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
