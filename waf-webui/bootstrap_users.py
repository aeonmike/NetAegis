import os
import sqlite3
from werkzeug.security import generate_password_hash

db_path = os.environ.get("DB_PATH", "/webui/data/users.db")

# Ensure directory exists
os.makedirs(os.path.dirname(db_path), exist_ok=True)

conn = sqlite3.connect(db_path)
c = conn.cursor()

# Create users table if it doesn't exist
c.execute("""
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL
)
""")

# Insert admin user if it doesn't exist
admin_user = 'admin'
admin_pass = 'admin123'  # change this later!
hashed_password = generate_password_hash(admin_pass)

c.execute("SELECT * FROM users WHERE username = ?", (admin_user,))
if not c.fetchone():
    c.execute("INSERT INTO users (username, password) VALUES (?, ?)", (admin_user, hashed_password))
    print(f"[✓] Admin user created with username '{admin_user}' and default password '{admin_pass}'")
else:
    print(f"[i] Admin user already exists")

conn.commit()
conn.close()
