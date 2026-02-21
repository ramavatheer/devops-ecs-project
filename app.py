from flask import Flask, jsonify, render_template
import socket
import os
import time
import psycopg2

app = Flask(__name__)

REQUEST_COUNT = 0

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_NAME = os.getenv("DB_NAME", "appdb")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "admin123")

def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        database=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )

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
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()
        conn.close()
        return jsonify(database_version=version)
    except Exception as e:
        return jsonify(error=str(e)), 500

@app.route("/api/load")
def simulate_load():
    time.sleep(3)
    return jsonify(message="Load simulation complete")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
