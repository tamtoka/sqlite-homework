"""Безопасная демонстрация SQL-инъекции в отдельной базе в памяти."""
import sqlite3

with sqlite3.connect(':memory:') as conn:
    conn.execute('CREATE TABLE products (sku TEXT, name TEXT)')
    conn.executemany('INSERT INTO products VALUES (?, ?)',
                     [('ABC-0001', 'Наушники'), ('ABC-0002', 'Кружка')])
    user_input = "' OR 1=1 --"

    # НЕБЕЗОПАСНО: ввод меняет смысл WHERE, возвращаются все товары.
    unsafe_sql = "SELECT sku, name FROM products WHERE sku = '" + user_input + "'"
    unsafe_rows = conn.execute(unsafe_sql).fetchall()

    # ПРАВИЛЬНО: ? передаёт ввод как значение, а не исполняемый SQL.
    safe_rows = conn.execute('SELECT sku, name FROM products WHERE sku = ?',
                             (user_input,)).fetchall()
    normal_rows = conn.execute('SELECT sku, name FROM products WHERE sku = ?',
                               ('ABC-0001',)).fetchall()
    print('Небезопасный запрос:', unsafe_sql)
    print('Конкатенация, найдено:', len(unsafe_rows), unsafe_rows)
    print('Параметризация, найдено:', len(safe_rows), safe_rows)
    print('Обычный поиск:', normal_rows)
    assert len(unsafe_rows) == 2 and safe_rows == [] and len(normal_rows) == 1
