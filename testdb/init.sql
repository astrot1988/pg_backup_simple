CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers(id),
  total_cents INTEGER NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO customers (email, full_name) VALUES
  ('alice@example.com', 'Alice Johnson'),
  ('bob@example.com', 'Bob Smith'),
  ('carol@example.com', 'Carol Brown');

INSERT INTO orders (customer_id, total_cents, status) VALUES
  (1, 1599, 'paid'),
  (1, 2599, 'paid'),
  (2, 999, 'pending'),
  (3, 4299, 'shipped');
