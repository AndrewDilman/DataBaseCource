import time
import random
from datetime import datetime

import psycopg2
from clickhouse_driver import Client

PG_CONFIG = {
    "host": "localhost",
    "port": 5432,
    "database": "marketplace_db",
    "user": "marketplace_user",
    "password": "marketplace_password",
}

CH_CONFIG = {
    "host": "localhost",
    "port": 9000,
    "user": "user",
    "password": "123",
    "database": "shop_analytics",
}


def get_pg_conn():
    return psycopg2.connect(**PG_CONFIG)


def get_ch_client():
    return Client(**CH_CONFIG)


def pick_customer(pg_cur):
    pg_cur.execute("SELECT user_id FROM users WHERE user_type = 'customer' ORDER BY random() LIMIT 1")
    return pg_cur.fetchone()[0]


def pick_good(pg_cur):
    pg_cur.execute("SELECT good_id, merch_id, caty_id FROM goods ORDER BY random() LIMIT 1")
    return pg_cur.fetchone()


def create_order(pg_cur, ch, customer_id, good_id, merch_id, category_id):
    now = datetime.utcnow()
    pg_cur.execute(
        "INSERT INTO orders (user_id, good_id) VALUES (%s, %s) RETURNING id",
        (customer_id, good_id),
    )
    order_id = pg_cur.fetchone()[0]
    pg_cur.execute(
        "INSERT INTO purchase_history (user_id, order_id) VALUES (%s, %s)",
        (customer_id, order_id),
    )
    price = float(random.randint(1000, 50000)) / 100.0
    ch.execute(
        "INSERT INTO order_events VALUES",
        [(order_id, customer_id, merch_id, good_id, category_id, now, price)],
    )
    return order_id


def create_review(pg_cur, ch, customer_id, good_id, merch_id, category_id, order_id):
    now = datetime.utcnow()
    rating = random.randint(1, 5)
    comment = random.choice(
        [
            "Отличный товар!",
            "Хорошее качество.",
            "Нормально за свои деньги.",
            "Есть недочеты.",
            "Не рекомендую.",
        ]
    )
    pg_cur.execute(
        "INSERT INTO reviews (user_id, good_id, rating, comment) "
        "VALUES (%s, %s, %s, %s) "
        "ON CONFLICT (user_id, good_id) DO NOTHING RETURNING id",
        (customer_id, good_id, rating, comment),
    )
    row = pg_cur.fetchone()
    if row is None:
        return None
    review_id = row[0]
    ch.execute(
        "INSERT INTO review_events VALUES",
        [(review_id, order_id, customer_id, good_id, merch_id, category_id, rating, comment, now)],
    )
    return review_id


def main():
    pg_conn = get_pg_conn()
    ch = get_ch_client()

    with pg_conn:
        with pg_conn.cursor() as cur:
            while True:
                for _ in range(3):
                    customer_id = pick_customer(cur)
                    good_id, merch_id, category_id = pick_good(cur)
                    create_order(cur, ch, customer_id, good_id, merch_id, category_id)

                for _ in range(2):
                    cur.execute("SELECT id, user_id, good_id FROM orders ORDER BY random() LIMIT 1")
                    order = cur.fetchone()
                    if not order:
                        continue
                    order_id, customer_id, good_id = order
                    cur.execute("SELECT merch_id, caty_id FROM goods WHERE good_id = %s", (good_id,))
                    merch_id, category_id = cur.fetchone()
                    create_review(cur, ch, customer_id, good_id, merch_id, category_id, order_id)

                pg_conn.commit()
                time.sleep(1)


if __name__ == "__main__":
    main()