/**
 * Seed для MongoDB: >500 документов суммарно.
 * Запуск (после старта контейнера):
 *   docker exec -i marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin < mongo-seed.js
 * или из хоста: mongosh "mongodb://admin:123@localhost:27017/marketplace?authSource=admin" mongo-seed.js
 */
db = db.getSiblingDB('marketplace');

// Вспомогательная коллекция: категории
const categories = [
  { category_id: 1, name: 'Электроника' },
  { category_id: 2, name: 'Одежда' },
  { category_id: 3, name: 'Дом' },
  { category_id: 4, name: 'Спорт' },
  { category_id: 5, name: 'Книги' },
];
db.categories.deleteMany({});
db.categories.insertMany(categories);

// Не трогаем products, если уже загружены из PG (migrate). Добавляем отзывы (reviews) для рейтинга.
// Если products пустая — вставляем минимум товаров для демо.
let productCount = db.products.countDocuments();
if (productCount === 0) {
  const merchants = [
    { merchant_id: 1, name: 'Магазин 1' },
    { merchant_id: 2, name: 'Магазин 2' },
    { merchant_id: 3, name: 'Магазин 3' },
  ];
  const names = ['Товар A', 'Товар B', 'Товар C', 'Товар D', 'Товар E', 'Товар F', 'Товар G', 'Товар H', 'Товар I', 'Товар J'];
  const products = [];
  for (let i = 1; i <= 200; i++) {
    products.push({
      good_id: i,
      name: names[(i - 1) % names.length] + ' ' + i,
      merchant_id: (i % 3) + 1,
      category_id: (i % 5) + 1,
      merchant_name: merchants[(i - 1) % 3].name,
      category_name: categories[(i % 5)].name,
      attributes: {},
      tags: [],
      created_at: new Date(),
      updated_at: new Date(),
    });
  }
  db.products.insertMany(products);
  productCount = 200;
}

// Отзывы: 300+ документов (чтобы суммарно с products было >500)
db.reviews.deleteMany({});
const reviews = [];
let id = 1;
for (let pid = 1; pid <= Math.min(productCount, 150); pid++) {
  const numReviews = 2 + (pid % 4);
  for (let r = 0; r < numReviews; r++) {
    reviews.push({
      review_id: id++,
      product_id: pid,
      user_id: (id % 100) + 1,
      rating: 1 + (id % 5),
      comment: 'Отзыв ' + id,
      created_at: new Date(),
    });
  }
}
if (reviews.length > 0) {
  db.reviews.insertMany(reviews);
}

const total = db.products.countDocuments() + db.reviews.countDocuments() + db.categories.countDocuments();
print('Seed готово. Документов: products=' + db.products.countDocuments() + ', reviews=' + db.reviews.countDocuments() + ', categories=' + db.categories.countDocuments() + ', всего=' + total);
