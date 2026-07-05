const router = require('express').Router();
const { body } = require('express-validator');
const { register, login, refresh, logout, getMe, updateMe } = require('../controllers/authController');
const { protect } = require('../middleware/auth');

const registerRules = [
  body('name').trim().isLength({ min: 2, max: 60 }).withMessage('Name must be 2–60 characters.'),
  body('email').isEmail().normalizeEmail().withMessage('Valid email required.'),
  body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters.'),
];

const loginRules = [
  body('email').isEmail().normalizeEmail().withMessage('Valid email required.'),
  body('password').notEmpty().withMessage('Password is required.'),
];

router.post('/register', registerRules, register);
router.post('/login', loginRules, login);
router.post('/refresh', refresh);
router.post('/logout', protect, logout);
router.get('/me', protect, getMe);
router.patch('/me', protect, updateMe);

module.exports = router;
