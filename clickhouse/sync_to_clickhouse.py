import psycopg2
import clickhouse_driver
from datetime import datetime, timedelta
import time
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Подключение к PostgreSQL
def get_postgres_connection():
    return psycopg2.connect(
        host="localhost",
        port=5432,
        database="marketplace_db",
        user="marketplace_user",
        password="marketplace_password"
    )

# Подключение к ClickHouse
def get_clickhouse_connection():
    return clickhouse_driver.Client(
        host='localhost',
        port=9000,
        user='user',
        password='123',
        database='shop_analytics'
    )

def sync_order_events():
    """Загружает существующие заказы из PostgreSQL в ClickHouse как события"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        # Получаем все заказы с информацией о товарах и категориях
        query = """
        SELECT 
            o.id as order_id,
            o.user_id,
            g.merch_id as merchant_id,
            g.good_id,
            g.caty_id as category_id,
            COALESCE(o.created_at, CURRENT_TIMESTAMP) as order_ts,
            1000.0 as price  -- Заглушка для цены, если нет поля
        FROM orders o
        JOIN goods g ON o.good_id = g.good_id
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            # Вставляем данные в ClickHouse
            ch_conn.execute(
                'INSERT INTO order_events VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} событий заказов в order_events")
        else:
            logger.info("Нет заказов для загрузки")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации order_events: {e}")
    finally:
        pg_conn.close()

def sync_review_events():
    """Загружает существующие отзывы из PostgreSQL в ClickHouse как события"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        # Получаем все отзывы с информацией о товарах и категориях
        query = """
        SELECT 
            r.id as review_id,
            COALESCE(o.id, 0) as order_id,  -- Если нет связи с заказом, ставим 0
            r.user_id,
            r.good_id,
            g.merch_id as merchant_id,
            g.caty_id as category_id,
            r.rating,
            COALESCE(r.comment, '') as comment,
            COALESCE(r.created_at, CURRENT_TIMESTAMP) as review_ts
        FROM reviews r
        JOIN goods g ON r.good_id = g.good_id
        LEFT JOIN orders o ON r.user_id = o.user_id AND r.good_id = o.good_id
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            ch_conn.execute(
                'INSERT INTO review_events VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} событий отзывов в review_events")
        else:
            logger.info("Нет отзывов для загрузки")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации review_events: {e}")
    finally:
        pg_conn.close()

def full_sync():
    """Полная синхронизация событий из PostgreSQL в ClickHouse"""
    logger.info("=" * 50)
    logger.info("Начало синхронизации событий PostgreSQL → ClickHouse")
    logger.info("=" * 50)
    
    sync_order_events()
    sync_review_events()
    
    logger.info("✓ Синхронизация завершена")
    logger.info("=" * 50)

if __name__ == "__main__":
    try:
        full_sync()
    except KeyboardInterrupt:
        logger.info("Синхронизация остановлена")