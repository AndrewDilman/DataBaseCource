# Redis - Паттерны кэширования

## Введение

Redis в проекте используется для кэширования тяжёлых запросов к MongoDB. Это ускоряет отклик API и снижает нагрузку на БД.

## Использование в проекте

### Подключение к Redis

```javascript
const Redis = require('ioredis');

const redis = new Redis({
    host: 'localhost',
    port: 6379
});
```

### Конфигурация в API

```javascript
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const redis = new Redis(REDIS_URL);
```

## Cache-Aside паттерн

### Чтение с кэшем

```javascript
const CACHE_KEY = 'report:top_by_categories';
const CACHE_TTL = 300; // 5 минут

async function getTopByCategories() {
    // 1. Проверить кэш
    const cached = await redis.get(CACHE_KEY);
    if (cached) {
        return JSON.parse(cached);
    }
    
    // 2. Если нет в кэше - запросить из БД
    const data = await computeTopByCategories();
    
    // 3. Сохранить в кэш
    await redis.setex(CACHE_KEY, CACHE_TTL, JSON.stringify(data));
    
    return data;
}
```

### Запись с инвалидацией

```javascript
// При создании/обновлении товара - инвалидировать кэш
await redis.del(CACHE_KEY);
```

## Паттерны кэширования

### 1. TTL (Time To Live)

```javascript
// Установить с TTL
await redis.setex('key', 300, 'value'); // 5 минут

// Проверить TTL
await redis.ttl('key'); // возвращает секунды
```

### 2. CacheStampede ( пробstampede)

Предотвращает множественные запросы при истечении TTL:

```javascript
async function getData(key, computeFn, ttl = 300) {
    const cached = await redis.get(key);
    if (cached) {
        return JSON.parse(cached);
    }
    
    // Использовать Mutex для предотвращения stampede
    const lockKey = key + ':lock';
    const lock = await redis.set(lockKey, '1', 'EX', 10, 'NX');
    
    if (lock) {
        const data = await computeFn();
        await redis.setex(key, ttl, JSON.stringify(data));
        await redis.del(lockKey);
        return data;
    }
    
    // Ждать пока другой поток вычислит
    await new Promise(r => setTimeout(r, 100));
    return getData(key, computeFn, ttl);
}
```

### 3. Write-Through

Запись одновременно в БД и кэш:

```javascript
async function saveProduct(product) {
    await db.products.insertOne(product);
    await redis.setex(`product:${product.id}`, 3600, JSON.stringify(product));
}
```

### 4. Write-Behind

Асинхронная запись:

```javascript
async function saveProduct(product) {
    await redis.lpush('pending_writes', JSON.stringify(product));
    // Фоновый обработчик
}

// Фоновый обработчик
async function processWrites() {
    while (true) {
        const data = await redis.rpop('pending_writes');
        if (data) {
            await db.products.insertOne(JSON.parse(data));
        }
        await sleep(100);
    }
}
```

## Ключи в проекте

### Report Cache

```javascript
const CACHE_KEY_TOP_BY_CATEGORIES = 'report:top_by_categories';
const CACHE_TTL_SEC = 300; // 5 минут
```

## Инвалидация кэша

### При обновлении товара

```javascript
app.post('/api/products', async (req, res) => {
    const doc = { ... };
    await db.collection('products').insertOne(doc);
    
    // Инвалидировать кэш отчёта
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
});
```

### При удалении товара

```javascript
app.delete('/api/products/:id', async (req, res) => {
    await db.collection('products').deleteOne({ good_id: id });
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
});
```

###手动ная инвалидация

```javascript
app.delete('/api/cache/report/top-by-categories', async (req, res) => {
    await redis.del(CACHE_KEY_TOP_BY_CATEGORIES);
    res.json({ invalidated: true });
});
```

## Примеры реализации

### Полный пример API

```javascript
const express = require('express');
const { MongoClient } = require('mongodb');
const Redis = require('ioredis');

const app = express();
app.use(express.json());

const CACHE_KEY = 'report:top_by_categories';
const CACHE_TTL = 300;

let db, redis;

async function connect() {
    const client = new MongoClient(process.env.MONGODB_URI);
    await client.connect();
    db = client.db();
    redis = new Redis(process.env.REDIS_URL);
}

// Получить товары
app.get('/api/products', async (req, res) => {
    const filter = req.query.category_id 
        ? { category_id: parseInt(req.query.category_id) } 
        : {};
    const products = await db.collection('products')
        .find(filter)
        .limit(20)
        .toArray();
    res.json(products);
});

// Отчёт с кэшем
app.get('/api/report/top-by-categories', async (req, res) => {
    const cached = await redis.get(CACHE_KEY);
    if (cached) {
        return res.json({ source: 'cache', data: JSON.parse(cached) });
    }
    
    const pipeline = [
        { $match: {} },
        { $group: { _id: '$category_name', count: { $sum: 1 } } },
        { $sort: { count: -1 } },
        { $limit: 10 }
    ];
    const data = await db.collection('products').aggregate(pipeline).toArray();
    
    await redis.setex(CACHE_KEY, CACHE_TTL, JSON.stringify(data));
    res.json({ source: 'db', data });
});

// Инвалидация при создании
app.post('/api/products', async (req, res) => {
    await db.collection('products').insertOne(req.body);
    await redis.del(CACHE_KEY);
    res.status(201).json({ ok: true });
});
```

## Мониторинг кэша

### Статистика

```bash
redis-cli INFO stats
```

### Ключи

```bash
# Все ключи
redis-cli KEYS *

# По паттерну
redis-cli KEYS report:*
```

### Использование памяти

```bash
redis-cli INFO memory
redis-cli MEMORY STATS
```

## Лучшие практики

1. **TTL** - устанавливайте разумное время жизни
2. **Инвалидация** - инвалидируйте при записи
3. **Сериализация** - используйте JSON
4. **Обработка ошибок** - проверяйте наличие данных в кэше
5. **Fallback** - при ошибке Redis используйте БД

## Подключение

```bash
docker exec -it marketplace-redis redis-cli
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [API/01_overview.md](../API/01_overview.md) - REST API