const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const Redis = require('ioredis');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://admin:123@localhost:27017/marketplace?authSource=admin';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// Ключ кэша для тяжёлого отчёта; инвалидируется при изменении продуктов
const CACHE_KEY_TOP_BY_CATEGORIES = 'report:top_by_categories';
const CACHE_TTL_SEC = 300; // 5 минут (при инвалидации при записи можно увеличить или убрать TTL)

let db;
let redis;

async function connect() {
  const client = new MongoClient(MONGODB_URI);
  await client.connect();
  db = client.db();
  redis = new Redis(REDIS_URL);
  console.log('MongoDB and Redis connected');
}

// --- REST: продукты ---

// GET /api/products — список (опционально ?category_id= & limit=)
app.get('/api/products', async (req, res) => {
  try {
    const categoryId = req.query.category_id ? parseInt(req.query.category_id, 10) : null;
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const filter = categoryId != null ? { category_id: categoryId } : {};
    const products = await db.collection('products')
      .find(filter)
      .project({ good_id: 1, name: 1, category_name: 1, merchant_name: 1, category_id: 1, merchant_id: 1 })
      .limit(limit)
      .toArray();
    res.json(products);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// GET /api/products/:id — один продукт по good_id или _id
app.get('/api/products/:id', async (req, res) => {
  try {
    const id = req.params.id;
    const byObjectId = /^[0-9a-fA-F]{24}$/.test(id);
    const product = await db.collection('products').findOne(
      byObjectId ? { _id: new ObjectId(id) } : { good_id: parseInt(id, 10) }
    );
    if (!product) return res.status(404).json({ error: 'Not found' });
    res.json(product);
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// POST /api/products — создать продукт и инвалидировать кэш отчёта
app.post('/api/products', async (req, res) => {
  try {
    const doc = {
      ...req.body,
      created_at: new Date(),
      updated_at: new Date(),
    };
    const result = await db.collection('products').insertOne(doc);
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
    res.status(201).json({ _id: result.insertedId, ...doc });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// PUT /api/products/:id — обновить по good_id; инвалидировать кэш
app.put('/api/products/:id', async (req, res) => {
  try {
    const goodId = parseInt(req.params.id, 10);
    if (Number.isNaN(goodId)) return res.status(400).json({ error: 'Invalid good_id' });
    const update = { $set: { ...req.body, updated_at: new Date() } };
    const result = await db.collection('products').updateOne(
      { good_id: goodId },
      update
    );
    if (result.matchedCount === 0) return res.status(404).json({ error: 'Not found' });
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
    res.json({ updated: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// --- Отчёт: топ по категориям (агрегация), кэш в Redis ---

async function computeTopByCategories() {
  const pipeline = [
    { $match: {} },
    { $group: { _id: '$category_name', count: { $sum: 1 }, names: { $push: '$name' } } },
    { $project: { category: '$_id', count: 1, _id: 0 } },
    { $sort: { count: -1 } },
    { $limit: 10 },
  ];
  return db.collection('products').aggregate(pipeline).toArray();
}

// GET /api/report/top-by-categories — кэшируется в Redis; инвалидация при POST/PUT продукта
app.get('/api/report/top-by-categories', async (req, res) => {
  try {
    const cached = await redis.get(CACHE_KEY_TOP_BY_CATEGORIES);
    if (cached) {
      return res.json({ source: 'cache', data: JSON.parse(cached) });
    }
    const data = await computeTopByCategories();
    await redis.setex(CACHE_KEY_TOP_BY_CATEGORIES, CACHE_TTL_SEC, JSON.stringify(data));
    res.json({ source: 'db', data });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Сброс кэша вручную (для отладки)
app.delete('/api/cache/report/top-by-categories', async (req, res) => {
  try {
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
    res.json({ invalidated: true });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// Health
app.get('/health', (req, res) => {
  res.json({ ok: true, redis: !!redis, mongo: !!db });
});

async function main() {
  await connect();
  app.listen(PORT, () => console.log(`API listening on ${PORT}`));
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
