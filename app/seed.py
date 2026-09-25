"""Idempotent seeding of Globomantics data into PostgreSQL and MongoDB.

Called on app startup. Safe to run repeatedly.
"""
import os
import time

import psycopg
from pymongo import MongoClient

PG_DSN = os.environ.get(
    "PG_DSN",
    "host=postgres port=5432 dbname=globomantics user=globo password=globo",
)
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://mongo:27017")
MONGO_DB = os.environ.get("MONGO_DB", "globomantics")

# Globomantics is the fictional company used throughout the course.
PRODUCTS = [
    ("Globomantics Router X100", "Networking", 129.99),
    ("Globomantics Switch S24", "Networking", 259.00),
    ("Globomantics Firewall F5", "Security", 899.50),
    ("Globomantics Access Point A2", "Networking", 89.95),
    ("Globomantics VPN Gateway G1", "Security", 1299.00),
    ("Globomantics NAS Cube", "Storage", 449.00),
]

ACCOUNTS = [
    # username, email, role
    ("gadmin", "gadmin@globomantics.example", "admin"),
    ("alice", "alice@globomantics.example", "user"),
    ("bob", "bob@globomantics.example", "user"),
    ("carol", "carol@globomantics.example", "user"),
]


def seed_postgres() -> None:
    last_err = None
    for _ in range(30):
        try:
            with psycopg.connect(PG_DSN) as conn:
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        CREATE TABLE IF NOT EXISTS products (
                            id SERIAL PRIMARY KEY,
                            name TEXT NOT NULL,
                            category TEXT NOT NULL,
                            price NUMERIC(10,2) NOT NULL
                        )
                        """
                    )
                    cur.execute("SELECT COUNT(*) FROM products")
                    if cur.fetchone()[0] == 0:
                        cur.executemany(
                            "INSERT INTO products (name, category, price) VALUES (%s, %s, %s)",
                            PRODUCTS,
                        )
                    conn.commit()
            return
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(2)
    raise RuntimeError(f"postgres seed failed: {last_err}")


def seed_mongo() -> None:
    last_err = None
    for _ in range(30):
        try:
            client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=2000)
            client.admin.command("ping")
            db = client[MONGO_DB]
            if db.users.count_documents({}) == 0:
                db.users.insert_many(
                    [
                        {"username": u, "email": e, "role": r}
                        for (u, e, r) in ACCOUNTS
                    ]
                )
            return
        except Exception as exc:  # noqa: BLE001
            last_err = exc
            time.sleep(2)
    raise RuntimeError(f"mongo seed failed: {last_err}")


def seed_all() -> None:
    seed_postgres()
    seed_mongo()
