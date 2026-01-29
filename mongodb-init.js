db = db.getSiblingDB('marketplace');

db.createUser({
  user: 'app_user',
  pwd: 'app_password',
  roles: [
    { role: 'readWrite', db: 'marketplace' }
  ]
});

db.createCollection('products');

db.products.createIndex({ good_id: 1 }, { unique: true });

print('MongoDB инициализирован: база marketplace, пользователь app_user, коллекция products');