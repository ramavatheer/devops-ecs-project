from flask import Flask, jsonify, render_template
import socket
import os
import time
import redis
import psycopg2
from psycopg2 import pool

app = Flask(__name__)

REQUEST_COUNT = 0

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "appdb")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "admin123")
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")

# Redis connection
redis_client = redis.Redis(host=REDIS_HOST, port=6379, decode_responses=True)

# PostgreSQL connection pooling
db_pool = pool.SimpleConnectionPool(
    1, 5,
    host=DB_HOST,
    database=DB_NAME,
    user=DB_USER,
    password=DB_PASSWORD
)

def get_db_connection():
    return db_pool.getconn()

def release_db_connection(conn):
    db_pool.putconn(conn)

def init_db():
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS visits (
            id SERIAL PRIMARY KEY,
            hostname TEXT,
            visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    conn.close()

@app.route("/")
def home():
    global REQUEST_COUNT
    REQUEST_COUNT += 1
    return render_template(
        "index.html",
        hostname=socket.gethostname(),
        request_count=REQUEST_COUNT
    )

@app.route("/health")
def health():
    return jsonify(status="healthy", container=socket.gethostname())

@app.route("/api/info")
def info():
    return jsonify(
        hostname=socket.gethostname(),
        requests_served=REQUEST_COUNT
    )

@app.route("/api/db")
def db_check():
    cached = redis_client.get("db_version")
    if cached:
        return jsonify(database_version=cached, source="cache")

    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()[0]
        release_db_connection(conn)

        redis_client.setex("db_version", 30, version)
        return jsonify(database_version=version, source="database")

    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route("/api/load")
def simulate_load():
    time.sleep(3)
    return jsonify(message="Load simulation complete")

if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
