db = db.getSiblingDB('marketplace');

db.createUser({
  user: 'app_user',
  pwd: 'app_password',
  roles: [
    { role: 'readWrite', db: 'marketplace' }
  ]
});

// --- Коллекции: products (основная), reviews (основная), categories (вспомогательная) ---
db.createCollection('products');
db.createCollection('reviews');
db.createCollection('categories');

// --- Индексы products ---
db.products.createIndex({ good_id: 1 }, { unique: true });
db.products.createIndex({ merchant_id: 1 });
db.products.createIndex({ category_id: 1 });
db.products.createIndex({ category_id: 1, merchant_id: 1 }); // составной под фасеты
// partial: только товары с указанной категорией (под запросы по каталогу)
db.products.createIndex(
  { category_id: 1, name: 1 },
  { name: 'idx_category_name', partialFilterExpression: { category_id: { $gt: 0 } } }
);

// --- Индексы reviews (рейтинг магазина) ---
db.reviews.createIndex({ product_id: 1 });
db.reviews.createIndex({ user_id: 1, product_id: 1 }, { unique: true });
db.reviews.createIndex({ product_id: 1, rating: 1 }); // под avg и фасеты

// --- Вспомогательная коллекция categories ---
db.categories.createIndex({ category_id: 1 }, { unique: true });
db.categories.createIndex({ name: 1 });

// --- TTL: коллекция для временных событий (пример) ---
db.createCollection('events');
db.events.createIndex({ created_at: 1 }, { expireAfterSeconds: 86400 }); // 1 день

// --- Валидация схемы: 2–3 бизнес-правила на коллекцию ---
db.runCommand({
  collMod: 'products',
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['name', 'merchant_id', 'category_id'],
      properties: {
        name: { bsonType: 'string', minLength: 1, maxLength: 500 },
        merchant_id: { bsonType: 'int', minimum: 1 },
        category_id: { bsonType: 'int', minimum: 1 },
        good_id: { bsonType: 'int', minimum: 1 }
      }
    }
  },
  validationLevel: 'moderate'
});

db.runCommand({
  collMod: 'reviews',
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['product_id', 'user_id', 'rating'],
      properties: {
        product_id: { bsonType: 'int', minimum: 1 },
        user_id: { bsonType: 'int', minimum: 1 },
        rating: { bsonType: 'int', minimum: 1, maximum: 5 },
        comment: { bsonType: 'string', maxLength: 2000 }
      }
    }
  },
  validationLevel: 'moderate'
});

print('MongoDB инициализирован: marketplace, products, reviews, categories, events (TTL); индексы и валидация схемы заданы.');