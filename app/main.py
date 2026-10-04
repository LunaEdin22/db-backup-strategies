import os

import psycopg2
from fastapi import FastAPI

app = FastAPI(title="Backup Demo")
DSN = os.environ["DATABASE_URL"]


def conn():
    return psycopg2.connect(DSN)


@app.on_event("startup")
def init():
    with conn() as c, c.cursor() as cur:
        cur.execute(
            """CREATE TABLE IF NOT EXISTS notes(
                id SERIAL PRIMARY KEY,
                text TEXT,
                created_at TIMESTAMP DEFAULT now())"""
        )


@app.post("/notes")
def add(text: str):
    with conn() as c, c.cursor() as cur:
        cur.execute("INSERT INTO notes(text) VALUES (%s) RETURNING id", (text,))
        return {"id": cur.fetchone()[0]}


@app.get("/notes")
def list_notes():
    with conn() as c, c.cursor() as cur:
        cur.execute(
            "SELECT id, text, created_at FROM notes ORDER BY id DESC LIMIT 50"
        )
        return cur.fetchall()


@app.get("/health")
def health():
    return {"status": "ok"}
