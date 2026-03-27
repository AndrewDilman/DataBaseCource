-- Примеры строк для JDBC Source (инкремент по id → топик db.event_outbox)
INSERT INTO event_outbox (event_type, entity_id, payload) VALUES
('OrderCreated', 'order-demo-1', '{"amount": 100}'::jsonb),
('BookIssued', 'book-demo-1', '{"isbn": "978-5-000"}'::jsonb);
