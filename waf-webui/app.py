from flask import Flask, render_template, redirect, url_for, request, session, flash
from werkzeug.security import check_password_hash
import sqlite3
import json
import os
import psutil
import subprocess
from datetime import datetime

app = Flask(__name__)
app.secret_key = '#netaegis8888'

DB_PATH = os.environ.get("DB_PATH", "/webui/data/users.db")
AUDIT_LOG_PATH = "/waf-logs/audit.log"
MODSEC_RULE_FILE = "/usr/local/nginx/conf/modsec/modsecurity.conf"
REVERSE_PROXY_DIR = "/usr/local/nginx/conf/proxies"

os.makedirs(REVERSE_PROXY_DIR, exist_ok=True)

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def check_service_status(service_name):
    try:
        result = subprocess.run(['pidof', service_name], stdout=subprocess.PIPE)
        return result.returncode == 0
    except Exception:
        return False

def get_system_stats():
    return {
        "cpu": psutil.cpu_percent(interval=1),
        "memory": psutil.virtual_memory().percent,
        "disk": psutil.disk_usage('/').percent
    }

@app.route('/', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        conn = get_db_connection()
        user = conn.execute('SELECT * FROM users WHERE username = ?', (username,)).fetchone()
        conn.close()
        if user and check_password_hash(user['password'], password):
            session['user'] = username
            return redirect(url_for('dashboard'))
        flash('Invalid credentials')
    return render_template('login.html')

@app.route('/dashboard')
def dashboard():
    if 'user' not in session:
        return redirect(url_for('login'))

    stats = get_system_stats()
    nginx_running = check_service_status("nginx")
    modsec_running = "Yes" if nginx_running else "Unknown"

    return render_template("dashboard.html", user=session['user'], stats=stats,
                           nginx_status="Running" if nginx_running else "Stopped",
                           modsec_status=modsec_running)

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/logs')
def view_logs():
    if 'user' not in session:
        return redirect(url_for('login'))

    logs = []
    try:
        with open(AUDIT_LOG_PATH, "r") as f:
            for line in f:
                try:
                    data = json.loads(line)
                    tx = data.get("transaction", {})
                    msg = tx.get("messages", [{}])[0]
                    logs.append({
                        "timestamp": tx.get("time_stamp"),
                        "ip": tx.get("client_ip"),
                        "method": tx.get("request", {}).get("method"),
                        "uri": tx.get("request", {}).get("uri"),
                        "code": tx.get("response", {}).get("http_code"),
                        "rule_id": msg.get("details", {}).get("ruleId"),
                        "message": msg.get("message"),
                        "severity": msg.get("details", {}).get("severity")
                    })
                except json.JSONDecodeError:
                    continue
    except FileNotFoundError:
        flash("Log file not found.", "danger")

    return render_template("logs.html", logs=logs)

@app.route('/rules', methods=['GET', 'POST'])
def edit_rules():
    if 'user' not in session:
        return redirect(url_for('login'))

    if request.method == 'POST' and 'rules' in request.form:
        rules_content = request.form.get('rules', '')
        try:
            with open(MODSEC_RULE_FILE, 'w') as f:
                f.write(rules_content)
            flash("ModSecurity global rules updated.", "success")
        except Exception as e:
            flash(f"Error writing rules: {e}", "danger")
        return redirect(url_for('edit_rules'))

    try:
        with open(MODSEC_RULE_FILE, 'r') as f:
            rules_content = f.read()
    except FileNotFoundError:
        rules_content = ''

    proxy_rules = []
    for fname in sorted(os.listdir(REVERSE_PROXY_DIR)):
        fpath = os.path.join(REVERSE_PROXY_DIR, fname)
        if os.path.isfile(fpath):
            with open(fpath, 'r') as f:
                proxy_rules.append({
                    "filename": fname,
                    "content": f.read()
                })

    return render_template("rules.html", rules=rules_content, proxy_rules=proxy_rules)

@app.route('/create_proxy_rule', methods=['POST'])
def create_proxy_rule():
    if 'user' not in session:
        return redirect(url_for('login'))

    path = request.form.get('path')
    target = request.form.get('target')
    enable_security = 'modsec_enabled' in request.form

    if not path or not target:
        flash("Both path and target are required.", "danger")
        return redirect(url_for('edit_rules'))

    filename = path.strip('/').replace('/', '_') or 'root'
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
    file_path = os.path.join(REVERSE_PROXY_DIR, f"{filename}_{timestamp}.conf")

    rule_block = f"""
    location {path} {{
        proxy_pass {target};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    """

    if enable_security:
        rule_block += """
        modsecurity on;
        modsecurity_rules_file /usr/local/nginx/conf/modsec/main.conf;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
        """

    rule_block += "\n}\n"

    try:
        with open(file_path, 'w') as f:
            f.write(rule_block)
        subprocess.run(["nginx", "-s", "reload"])
        flash("Reverse proxy rule created and NGINX reloaded.", "success")
    except Exception as e:
        flash(f"Failed to create rule: {str(e)}", "danger")

    return redirect(url_for('edit_rules'))

@app.route('/edit_proxy_rule/<filename>', methods=['POST'])
def edit_proxy_rule(filename):
    if 'user' not in session:
        return redirect(url_for('login'))

    path = request.form.get('edit_path')
    target = request.form.get('edit_target')
    enable_security = 'edit_modsec_enabled' in request.form

    fpath = os.path.join(REVERSE_PROXY_DIR, filename)
    if not os.path.exists(fpath):
        flash("Proxy rule not found.", "danger")
        return redirect(url_for('edit_rules'))

    rule_block = f"""
    location {path} {{
        proxy_pass {target};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    """

    if enable_security:
        rule_block += """
        modsecurity on;
        modsecurity_rules_file /usr/local/nginx/conf/modsec/main.conf;

        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-XSS-Protection "1; mode=block";
        add_header X-Content-Type-Options "nosniff";
        """

    rule_block += "\n}\n"

    try:
        with open(fpath, 'w') as f:
            f.write(rule_block)
        subprocess.run(["nginx", "-s", "reload"])
        flash("Proxy rule updated and NGINX reloaded.", "success")
    except Exception as e:
        flash(f"Failed to update rule: {str(e)}", "danger")

    return redirect(url_for('edit_rules'))

@app.route('/delete_proxy_rule/<filename>', methods=['POST'])
def delete_proxy_rule(filename):
    if 'user' not in session:
        return redirect(url_for('login'))

    fpath = os.path.join(REVERSE_PROXY_DIR, filename)
    if os.path.exists(fpath):
        try:
            os.remove(fpath)
            subprocess.run(["nginx", "-s", "reload"])
            flash("Proxy rule deleted and NGINX reloaded.", "success")
        except Exception as e:
            flash(f"Failed to delete rule: {str(e)}", "danger")
    else:
        flash("Proxy rule file not found.", "danger")

    return redirect(url_for('edit_rules'))

@app.route('/restart')
def restart_waf():
    if 'user' not in session:
        return redirect(url_for('login'))

    try:
        subprocess.run(['nginx', '-s', 'reload'], check=True)
        flash("WAF (NGINX) restarted successfully.", "success")
    except subprocess.CalledProcessError as e:
        flash(f"Failed to restart WAF: {e}", "danger")

    return redirect(url_for('dashboard'))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
