# ClickHouse Analytics для маркетплейса

Привет! Здесь описано, как работает наша аналитическая система на ClickHouse. Вся идея в том, что PostgreSQL хранит текущее состояние (заказы, отзывы), а ClickHouse анализирует эти данные в реальном времени.

## Архитектура

### PostgreSQL — твой кассир
PostgreSQL — это **транзакционная база**, которая хранит:
- **Справочники**: категории товаров, пользователи, товары, адреса
- **События**: заказы и отзывы (создаются генератором)

PostgreSQL гарантирует, что все данные сохранятся и будут консистентны. Но для анализа потоков данных её недостаточно — там это медленно.

### ClickHouse — твой аналитик
ClickHouse — это **аналитическая база** (OLAP), которая:
- **Получает события** о заказах и отзывах
- **Агрегирует их** в реальном времени
- **Отвечает на сложные вопросы** за миллисекунды

Например: "Какие категории товаров падают в рейтинге за последние 7 дней?" — ClickHouse ответит быстро, потому что он специально для этого создан.

## Таблицы и их связи

```
PostgreSQL (текущее состояние)
  ├── orders (заказы)
  └── reviews (отзывы)
         ↓
         ↓ (события потом)
         ↓
ClickHouse (анализ)
  ├── order_events (события заказов)
  ├── review_events (события отзывов)
         ↓
         ↓ (материализованные views)
         ↓
  ├── category_daily_stats (статистика по категориям)
  ├── merchant_daily_stats (статистика по продавцам)
  └── product_stats (статистика по товарам)
```

### order_events и review_events — сырые события
```sql
order_events:
  order_id=1, user_id=101, category_id=5, order_ts=2024-01-15 10:00, price=1500

review_events:
  review_id=1, good_id=1, category_id=5, rating=5, review_ts=2024-01-15 11:00
```

Это просто _сырые данные о каждом действии_. Если за минуту создано 180 заказов, то будет 180 строк в `order_events`.

### category_daily_stats, merchant_daily_stats, product_stats — агрегаты
Это таблицы, которые **суммируют** события за день. Например:

```sql
category_daily_stats:
  date=2024-01-15, category_id=5, orders_count=180, reviewed_count=45, rating_sum=210, review_count=45
```

Вместо 180 отдельных заказов в один ряд! Это позволяет быстро отвечать на вопросы типа "сколько заказов в категории за день".

## Как это работает: материализованные views (MV)

MV — это **автоматические конвейеры**, которые преобразуют события в агрегаты.

### Пример: mv_category_orders

```sql
CREATE MATERIALIZED VIEW mv_category_orders
TO category_daily_stats
AS
SELECT
    toDate(order_ts) AS date,
    category_id,
    1 AS orders_count,
    0 AS reviewed_count,
    0 AS rating_sum,
    0 AS review_count
FROM order_events;
```

Что это делает:
1. **Слушает** `order_events`
2. Когда туда добавляется новая строка, берёт её
3. Преобразует: берёт дату, категорию, и генерирует `(date, category, +1 заказ, 0 отзывов, 0 рейтинга, 0 ревью)`
4. **Отправляет результат** в `category_daily_stats`

### Пример: mv_category_reviews

Делает же самое, но для отзывов:

```sql
CREATE MATERIALIZED VIEW mv_category_reviews
TO category_daily_stats
AS
SELECT
    toDate(review_ts) AS date,
    category_id,
    0 AS orders_count,
    1 AS reviewed_count,
    rating AS rating_sum,
    1 AS review_count
FROM review_events;
```

Генерирует: `(date, category, 0 заказов, +1 отзыв, +рейтинг, +1 ревью)`

### Как они работают вместе

`category_daily_stats` использует `SummingMergeTree` — это движок, который **суммирует** приходящие данные:

```
День 1:
  Заказ 1 → mv_category_orders → (2024-01-15, category=5, orders=1, 0, 0, 0)
                                 ↓
                             category_daily_stats
  Отзыв 1 (рейтинг 5) → mv_category_reviews → (2024-01-15, category=5, 0, reviewed=1, rating=5, 1)
                                              ↓
                                          category_daily_stats
  
Результат в category_daily_stats:
  (2024-01-15, category=5, orders=1, reviewed=1, rating_sum=5, review_count=1)
```

То ест если за день 180 заказов и 45 отзывов, в `category_daily_stats` будет **одна** строка с суммарными данными!

## Скрипты

### event_generator.py — рождает события
```python
python event_generator.py
```

Этот скрипт:
- Создаёт **3 заказа в секунду** в PostgreSQL
- Создаёт **2 отзыва в секунду** в PostgreSQL
- Одновременно пишет эти события в ClickHouse (`order_events` и `review_events`)

Работает в бесконечном цикле, оставляет трейл в ClickHouse.

### sync_to_clickhouse.py — синхронизирует исторические данные
```python
python sync_to_clickhouse.py
```

Этот скрипт запускается **один раз в начале**:
- Берёт все существующие заказы из PostgreSQL
- Берёт все существующие отзывы из PostgreSQL
- Загружает их в `order_events` и `review_events` в ClickHouse

Агрегаты (`category_daily_stats`, `merchant_daily_stats`, `product_stats`) обновятся **автоматически** через MV.

## Запуск

### 1. Поднимаешь контейнеры
```bash
docker-compose down -v
docker-compose up -d
sleep 10
```

Ждёшь, пока PostgreSQL загенерирует справочники (категории, товары, пользователи).

### 2. Синхронизируешь исторические данные (если они есть)
```bash
python sync_to_clickhouse.py
```

Вывод:
```
==================================================
Начало синхронизации событий PostgreSQL → ClickHouse
==================================================
Нет заказов для загрузки
Нет отзывов для загрузки
(ТУТ МОГУТ БЫТЬ ОШИБКИ ВСЯКИЕ И ЭТО НОРМ. если нет заказов и постгрес пустой то это норм)
✓ Синхронизация завершена
==================================================
```

(Если заказов нет, это нормально — они будут создаваться генератором)

### 3. Запускаешь генератор событий
```bash
python event_generator.py
```

Вывод:
```
Генератор работает... Создаёт события...
```

Процесс работает бесконечно. Нажимаешь `Ctrl+C` когда хочешь остановить.

### 4. Проверяешь данные в ClickHouse (в другом терминале)

Подключиться к ClickHouse через браузер:
```
http://localhost:8123/
User: user
Password: 123
```

Или через консоль:
```bash
docker exec -it marketplace_clickhouse clickhouse-client --user user --password 123
```

Примеры запросов:

**Сколько заказов накопилось?**
```sql
SELECT count() FROM shop_analytics.order_events;
```

**Статистика по категориям за сегодня**
```sql
SELECT 
  date, 
  category_id, 
  orders_count, 
  reviewed_count,
  round(rating_sum / review_count, 2) as avg_rating
FROM shop_analytics.category_daily_stats
WHERE date >= today()
ORDER BY orders_count DESC;
```

**Топ товаров по количеству отзывов**
```sql
SELECT 
  good_id, 
  category_id, 
  total_orders, 
  review_count,
  round(rating_sum / review_count, 2) as avg_rating
FROM shop_analytics.product_stats
WHERE review_count > 0
ORDER BY review_count DESC
LIMIT 10;
```

## Чек-лист перед демо преподавателю

- [ ] Контейнеры подняты (`docker-compose ps` показывает оба сервиса)
- [ ] PostgreSQL инициализирован и заполнен справочниками
- [ ] ClickHouse таблицы созданы и пусты (или синхронизированы)
- [ ] Генератор работает (`event_generator.py` запущен)
- [ ] Данные накапливаются в `order_events` и `review_events`
- [ ] Агрегаты обновляются в реальном времени через MV

## Вопросы на защиту

**Q: Зачем две базы?**
A: PostgreSQL гарантирует консистентность транзакций, ClickHouse — скорость анализа. PostgreSQL медленный для аналитики, ClickHouse быстрый, но не подходит для транзакций.

**Q: Почему материализованные views?**
A: MV автоматически преобразуют события в агрегаты. Без них пришлось бы вручную писать SQL запросы для обновления статистики.

**Q: Как ClickHouse узнаёт про новые события?**
A: Генератор (`event_generator.py`) одновременно пишет в PostgreSQL и ClickHouse. Новые события сразу попадают в `order_events`/`review_events`, а MV мгновенно обновляют агрегаты.

**Q: А если генератор упадёт?**
A: PostgreSQL продолжит хранить данные. Когда генератор перезапустишь, он загрузит новые события. ClickHouse не потеряет уже накопленные данные.

**Q: Можно ли запрашивать ClickHouse напрямую?**
A: Да, он открыт на портах `8123` (HTTP) и `9000` (native TCP). Можно подключиться любым клиентом.

---

**Готово!** Система работает, статистика накапливается в реальном времени. 🚀