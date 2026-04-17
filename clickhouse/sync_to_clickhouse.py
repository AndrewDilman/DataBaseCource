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

def sync_order_analytics():
    """Загружает данные заказов с полной информацией в ClickHouse"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        # Получаем все данные о заказах с информацией о товарах, категориях и продавцах
        query = """
        SELECT 
            o.id as order_id,
            o.user_id,
            g.merch_id as merchant_id,
            g.good_id,
            g.caty_id as category_id,
            c.name as category_name,
            u.name as merchant_name,
            g.name as good_name,
            COALESCE(r.rating, 0) as rating,
            CASE WHEN r.id IS NOT NULL THEN 1 ELSE 0 END as has_review,
            CURRENT_DATE as order_date,
            CURRENT_TIMESTAMP as order_timestamp
        FROM orders o
        JOIN goods g ON o.good_id = g.good_id
        JOIN categories c ON g.caty_id = c.caty_id
        JOIN users u ON g.merch_id = u.user_id
        LEFT JOIN reviews r ON o.user_id = r.user_id AND o.good_id = r.good_id
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            # Вставляем данные в ClickHouse
            ch_conn.execute(
                'INSERT INTO order_analytics VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} записей в order_analytics")
        else:
            logger.info("Нет новых заказов для загрузки")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации order_analytics: {e}")
    finally:
        pg_conn.close()

def sync_category_stats():
    """Загружает агрегированные статистики по категориям"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        query = """
        SELECT 
            CURRENT_DATE as date,
            c.caty_id as category_id,
            c.name as category_name,
            COUNT(o.id) as orders_count,
            COALESCE(AVG(r.rating), 0) as avg_rating,
            COUNT(CASE WHEN r.id IS NOT NULL THEN 1 END) as reviewed_count
        FROM categories c
        LEFT JOIN goods g ON c.caty_id = g.caty_id
        LEFT JOIN orders o ON g.good_id = o.good_id
        LEFT JOIN reviews r ON o.user_id = r.user_id AND o.good_id = r.good_id
        GROUP BY c.caty_id, c.name
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            ch_conn.execute(
                'INSERT INTO category_daily_stats VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} записей в category_daily_stats")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации category_daily_stats: {e}")
    finally:
        pg_conn.close()

def sync_merchant_stats():
    """Загружает статистику по продавцам"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        query = """
        SELECT 
            CURRENT_DATE as date,
            u.user_id as merchant_id,
            u.name as merchant_name,
            COUNT(o.id) as orders_count,
            COALESCE(AVG(r.rating), 0) as avg_rating,
            COUNT(CASE WHEN r.id IS NOT NULL THEN 1 END) as reviewed_orders
        FROM users u
        LEFT JOIN goods g ON u.user_id = g.merch_id
        LEFT JOIN orders o ON g.good_id = o.good_id
        LEFT JOIN reviews r ON o.user_id = r.user_id AND o.good_id = r.good_id
        WHERE u.user_type = 'merchant'
        GROUP BY u.user_id, u.name
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            ch_conn.execute(
                'INSERT INTO merchant_daily_stats VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} записей в merchant_daily_stats")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации merchant_daily_stats: {e}")
    finally:
        pg_conn.close()

def sync_product_stats():
    """Загружает статистику по товарам"""
    pg_conn = get_postgres_connection()
    ch_conn = get_clickhouse_connection()
    
    try:
        pg_cursor = pg_conn.cursor()
        
        query = """
        SELECT 
            g.good_id,
            g.name as good_name,
            g.caty_id as category_id,
            g.merch_id as merchant_id,
            COUNT(o.id) as total_orders,
            COALESCE(AVG(r.rating), 0) as avg_rating,
            COUNT(r.id) as review_count
        FROM goods g
        LEFT JOIN orders o ON g.good_id = o.good_id
        LEFT JOIN reviews r ON g.good_id = r.good_id
        GROUP BY g.good_id, g.name, g.caty_id, g.merch_id
        """
        
        pg_cursor.execute(query)
        rows = pg_cursor.fetchall()
        
        if rows:
            ch_conn.execute(
                'INSERT INTO product_stats VALUES',
                rows,
                settings={'max_insert_threads': 2}
            )
            logger.info(f"✓ Загружено {len(rows)} записей в product_stats")
        
        pg_cursor.close()
        
    except Exception as e:
        logger.error(f"Ошибка при синхронизации product_stats: {e}")
    finally:
        pg_conn.close()

def full_sync():
    """Полная синхронизация всех таблиц"""
    logger.info("=" * 50)
    logger.info("Начало синхронизации PostgreSQL → ClickHouse")
    logger.info("=" * 50)
    
    sync_order_analytics()
    sync_category_stats()
    sync_merchant_stats()
    sync_product_stats()
    
    logger.info("✓ Синхронизация завершена")
    logger.info("=" * 50)

if __name__ == "__main__":
    try:
        full_sync()
    except KeyboardInterrupt:
        logger.info("Синхронизация остановлена")