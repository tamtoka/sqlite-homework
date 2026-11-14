"""Создание учебной SQLite БД. Запуск из любой папки: python code/seed.py."""
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
DB = ROOT / 'shop.sqlite3'
SCHEMA = '''
PRAGMA foreign_keys = ON;
CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    sku TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    price REAL NOT NULL CHECK(price >= 0),
    base_price REAL NOT NULL CHECK(base_price >= 0),
    stock INTEGER NOT NULL DEFAULT 0 CHECK(stock >= 0),
    is_test INTEGER NOT NULL DEFAULT 0 CHECK(is_test IN (0, 1))
);
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK(quantity > 0),
    unit_price REAL NOT NULL CHECK(unit_price >= 0),
    ordered_at TEXT NOT NULL
);
CREATE INDEX idx_orders_product_id ON orders(product_id);
'''


def seed(path):
    # Не перезаписываем существующую базу и не удаляем данные пользователя.
    if path.exists():
        raise SystemExit(f'База уже существует: {path}. Для новой копии укажите другой путь.')
    categories = ['Электроника', 'Дом', 'Спорт', 'Книги', 'Одежда', 'Канцелярия']
    names = ['Наушники', 'Кружка', 'Мяч', 'Учебник', 'Футболка', 'Ручка']
    with sqlite3.connect(path) as conn:
        conn.executescript(SCHEMA)
        products = []
        for i in range(1, 121):
            group = (i - 1) % 6
            price = round(150 + group * 200 + i * 37.5, 2)
            products.append((f'ABC-{i:04d}', f'{names[group]}, модель {(i-1)//6+1:02d}',
                             categories[group], price, price, 5 + i % 26))
        # executemany связывает данные с ?; строки не склеиваются с SQL.
        conn.executemany('''INSERT INTO products
            (sku, name, category, price, base_price, stock) VALUES (?, ?, ?, ?, ?, ?)''', products)
        for i in range(1, 37):
            product_id = ((i - 1) * 7) % 120 + 1
            price = conn.execute('SELECT price FROM products WHERE id = ?', (product_id,)).fetchone()[0]
            conn.execute('''INSERT INTO orders (product_id, quantity, unit_price, ordered_at)
                VALUES (?, ?, ?, ?)''', (product_id, 1 + i % 4, price, f'2026-11-{1+(i-1)%12:02d}'))
    print(f'Создано: {path}; товаров: 120; заказов: 36')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=DB, help='Путь для новой базы')
    seed(parser.parse_args().db.resolve())
