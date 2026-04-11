# MongoDB - Валидация схемы

## Введение

MongoDB поддерживает валидацию схемы через JSON Schema. Это позволяет обеспечить целостность данных без использования фиксированной схемы.

## Уровни валидации

| Level | Описание |
|-------|----------|
| off | Валидация отключена |
| strict | Все операции валидируются (по умолчанию) |
| moderate | Валидируются только при update/insert |

## Валидация в проекте

### Коллекция products

```javascript
db.runCommand({
    collMod: "products",
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["name", "merchant_id", "category_id"],
            properties: {
                name: { 
                    bsonType: "string", 
                    minLength: 1, 
                    maxLength: 500 
                },
                merchant_id: { 
                    bsonType: "int", 
                    minimum: 1 
                },
                category_id: { 
                    bsonType: "int", 
                    minimum: 1 
                },
                good_id: { 
                    bsonType: "int", 
                    minimum: 1 
                }
            }
        }
    },
    validationLevel: "moderate"
});
```

### Коллекция reviews

```javascript
db.runCommand({
    collMod: "reviews",
    validator: {
        $jsonSchema: {
            bsonType: "object",
            required: ["product_id", "user_id", "rating"],
            properties: {
                product_id: { 
                    bsonType: "int", 
                    minimum: 1 
                },
                user_id: { 
                    bsonType: "int", 
                    minimum: 1 
                },
                rating: { 
                    bsonType: "int", 
                    minimum: 1, 
                    maximum: 5 
                },
                comment: { 
                    bsonType: "string", 
                    maxLength: 2000 
                }
            }
        }
    },
    validationLevel: "moderate"
});
```

## JSON Schema типы

### Основные типы

| BSON тип | Описание |
|---------|----------|
| object | Документ |
| array | Массив |
| string | Строка |
| int | 32-bit целое |
| long | 64-bit целое |
| double | Число с плавающей точкой |
| bool | Булево |
| date | Дата |
| null | Null |
| binData | Бинарные данные |
| objectId | ObjectId |
| regex | Regex |

###Типы в validators

```javascript
{
    bsonType: ["string", "null"]  // несколько типов
}
```

## Ограничения (properties)

### string

```javascript
properties: {
    name: {
        bsonType: "string",
        minLength: 1,
        maxLength: 500,
        pattern: "^[A-Z].*"  // regex
    }
}
```

### number

```javascript
properties: {
    price: {
        bsonType: ["int", "double"],
        minimum: 0,
        maximum: 1000000
    }
}
```

### array

```javascript
properties: {
    tags: {
        bsonType: "array",
        minItems: 0,
        maxItems: 10,
        items: {
            bsonType: "string"
        }
    }
}
```

### object

```javascript
properties: {
    attributes: {
        bsonType: "object",
        additionalProperties: {
            bsonType: "string"
        }
    }
}
```

## required (обязательные поля)

```javascript
{
    required: ["name", "merchant_id", "category_id"]
}
```

## Добавление валидации

### К новой коллекции

```javascript
db.createCollection("products", {
    validator: {
        $jsonSchema: { ... }
    },
    validationLevel: "moderate"
});
```

### К существующей

```javascript
db.runCommand({
    collMod: "products",
    validator: {
        $jsonSchema: { ... }
    },
    validationLevel: "moderate"
});
```

## Просмотр валидации

```javascript
db.products.validate();
db.products.validate({ full: true });
```

## Ошибки валидации

При вставке невалидного документа:

```javascript
db.products.insertOne({ name: "" });
// WriteResult({
//    "nInserted": 0,
//    "writeError": {
//        "code": 121,
//        "errmsg": "Document failed validation"
//    }
// })
```

## Примеры

### Валидный документ

```javascript
db.products.insertOne({
    name: "Смартфон",
    merchant_id: 1,
    category_id: 1,
    good_id: 1
});
// Success
```

### Невалидный документ

```javascript
db.products.insertOne({
    name: "",  // too short
    merchant_id: 1,
    category_id: 1,
    good_id: 1
});
// Error: Document failed validation
```

### Проверка перед вставкой

```javascript
function insertProduct(doc) {
    const schema = {
        bsonType: "object",
        required: ["name", "merchant_id", "category_id"],
        properties: {
            name: { bsonType: "string", minLength: 1 },
            merchant_id: { bsonType: "int", minimum: 1 },
            category_id: { bsonType: "int", minimum: 1 }
        }
    };
    
    // Использовать $jsonSchema в запросе
    const isValid = db.products.find({
        $jsonSchema: schema
    }).limit(0).count() >= 0;
    
    if (isValid) {
        db.products.insertOne(doc);
    } else {
        print("Invalid document");
    }
}
```

## Ограничения

1. Только JSON Schema draft 4
2. Некоторые функции не поддерживаются
3. Работает только для insert/update

## Подключение

```bash
docker exec -it marketplace-mongodb mongosh -u admin -p 123 --authenticationDatabase admin
```

## Смотрите также

- [01_basics.md](01_basics.md) - Базовые понятия
- [02_collections.md](02_collections.md) - Коллекции
- [04_indexes.md](04_indexes.md) - Индексы