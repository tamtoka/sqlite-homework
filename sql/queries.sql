-- SQLite. Сначала запустите code/seed.py и откройте shop.sqlite3.
-- Выполняйте весь скрипт либо выделенный блок. Все UPDATE/DELETE имеют WHERE.
PRAGMA foreign_keys = ON;

-- Структура таблиц (также создаётся генератором seed.py).
CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price REAL NOT NULL CHECK(price >= 0),
    base_price REAL NOT NULL CHECK(base_price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
    is_test INTEGER NOT NULL DEFAULT 0 CHECK(is_test IN (0, 1))
);
CREATE TABLE IF NOT EXISTS orders (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    unit_price REAL NOT NULL CHECK(unit_price >= 0),
    ordered_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_orders_product_id ON orders(product_id);

-- 1. Три отдельных INSERT вручную. OR IGNORE позволяет повторять скрипт.
INSERT OR IGNORE INTO products (sku, name, category, price, base_price, stock)
VALUES ('MANUAL-001', 'Беспроводная мышь', 'Электроника', 1490, 1490, 15);

INSERT OR IGNORE INTO products (sku, name, category, price, base_price, stock)
VALUES ('MANUAL-002', 'Настольная лампа', 'Дом', 2390, 2390, 8);

INSERT OR IGNORE INTO products (sku, name, category, price, base_price, stock, is_test)
VALUES ('TEST-DELETE-001', 'Тестовый товар для удаления', 'Тест', 1, 1, 0, 1);

-- 2. Одна массовая вставка: 12 товаров одним INSERT ... SELECT.
WITH RECURSIVE numbers(n) AS (
    SELECT 1 UNION ALL SELECT n + 1 FROM numbers WHERE n < 12
)
INSERT OR IGNORE INTO products (sku, name, category, price, base_price, stock)
SELECT printf('BULK-%03d', n), 'Блокнот, модель ' || n,
       'Канцелярия', 100 + n * 10, 100 + n * 10, 20 + n
FROM numbers;

-- 3. Скидка 10% категории. От базовой цены: повторный запуск не накапливает скидку.
UPDATE products
SET price = ROUND(base_price * 0.90, 2)
WHERE category = 'Электроника' AND is_test = 0;

-- 4. Исправление цены конкретного артикула.
UPDATE products
SET price = 2190, base_price = 2190
WHERE sku = 'MANUAL-002' AND is_test = 0;

-- 5. Пополнение остатка конкретного товара до целевого значения.
UPDATE products
SET stock = 30
WHERE sku = 'MANUAL-001' AND stock < 30 AND is_test = 0;

-- 6. Безопасное удаление: сначала проверяем точный набор строк.
SELECT id, sku, name, is_test FROM products
WHERE sku = 'TEST-DELETE-001' AND is_test = 1;
DELETE FROM products
WHERE sku = 'TEST-DELETE-001' AND is_test = 1;

-- 7. Топ-10 доступных товаров дороже 1000 рублей.
SELECT sku, name, category, price, stock
FROM products
WHERE price > 1000 AND stock > 0 AND is_test = 0
ORDER BY price DESC, sku ASC
LIMIT 10;

-- 8. Агрегация: категории, в которых больше пяти товаров.
SELECT category, COUNT(*) AS product_count,
       ROUND(AVG(price), 2) AS average_price
FROM products
WHERE is_test = 0
GROUP BY category
HAVING COUNT(*) > 5
ORDER BY product_count DESC, category;

-- 9. Поиск по шаблону без учёта регистра для латинских SKU.
-- Встроенный UPPER SQLite поддерживает ASCII; для кириллицы нужна ICU/иная нормализация.
SELECT sku, name, category, price
FROM products
WHERE UPPER(sku) LIKE UPPER('abc%')
ORDER BY sku
LIMIT 15;

-- 10. JOIN: позиции заказов с названием товара и суммой позиции.
-- unit_price хранит цену на момент покупки, независимо от текущей цены товара.
SELECT o.id AS order_id, o.ordered_at, p.name, p.category,
       o.quantity, o.unit_price,
       ROUND(o.quantity * o.unit_price, 2) AS line_total
FROM orders AS o
JOIN products AS p ON p.id = o.product_id
ORDER BY o.id;

-- 11. JOIN и суммы продаж по категориям.
SELECT p.category, COUNT(*) AS order_count,
       SUM(o.quantity) AS units_sold,
       ROUND(SUM(o.quantity * o.unit_price), 2) AS revenue
FROM orders AS o
JOIN products AS p ON p.id = o.product_id
GROUP BY p.category
ORDER BY revenue DESC, p.category;

-- 12. Контроль: после полного скрипта 134 товара, 36 заказов, 0 тестовых строк.
SELECT COUNT(*) AS product_count, SUM(is_test) AS test_product_count FROM products;
SELECT COUNT(*) AS order_count FROM orders;
