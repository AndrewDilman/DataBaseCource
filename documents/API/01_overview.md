# API - Обзор

## Введение

REST API сервис построен на Node.js/Express и взаимодействует с MongoDB и Redis.

## Зависимости

```json
{
    "express": "^4.18.2",
    "mongodb": "^6.3.0",
    "ioredis": "^5.3.2"
}
```

## Конфигурация

```javascript
const PORT = process.env.PORT || 4000;
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://admin:123@localhost:27017/marketplace?authSource=admin';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
```

## Подключение

```javascript
const { MongoClient, ObjectId } = require('mongodb');
const Redis = require('ioredis');

let db, redis;

async function connect() {
    const client = new MongoClient(MONGODB_URI);
    await client.connect();
    db = client.db();
    redis = new Redis(REDIS_URL);
}
```

## Запуск

```bash
# Docker
docker-compose up -d api

# Локально
npm start
```

## Порт

API работает на порту 4000.

## Запросы

- GET /health - проверка здоровья

## Смотрите также

- [02_endpoints.md](02_endpoints.md) - Эндпоинты