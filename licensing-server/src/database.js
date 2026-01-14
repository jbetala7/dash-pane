const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'data', 'licenses.db');
const dataDir = path.join(__dirname, '..', 'data');

// Ensure data directory exists
if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
}

let db = null;

async function initDatabase() {
    const SQL = await initSqlJs();

    // Load existing database or create new one
    if (fs.existsSync(dbPath)) {
        const fileBuffer = fs.readFileSync(dbPath);
        db = new SQL.Database(fileBuffer);
    } else {
        db = new SQL.Database();
    }

    // Create tables
    db.run(`
        CREATE TABLE IF NOT EXISTS licenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_key TEXT UNIQUE NOT NULL,
            email TEXT NOT NULL,
            phone TEXT,
            razorpay_payment_id TEXT,
            razorpay_order_id TEXT,
            amount INTEGER,
            currency TEXT DEFAULT 'INR',
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_active INTEGER DEFAULT 1
        )
    `);

    db.run(`
        CREATE TABLE IF NOT EXISTS activations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            license_id INTEGER NOT NULL,
            hardware_id TEXT NOT NULL,
            machine_name TEXT,
            activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            last_validated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            is_active INTEGER DEFAULT 1,
            FOREIGN KEY (license_id) REFERENCES licenses(id),
            UNIQUE(license_id, hardware_id)
        )
    `);

    // Create indexes
    db.run(`CREATE INDEX IF NOT EXISTS idx_licenses_key ON licenses(license_key)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_licenses_email ON licenses(email)`);
    db.run(`CREATE INDEX IF NOT EXISTS idx_activations_hardware ON activations(hardware_id)`);

    // Save to file
    saveDatabase();

    console.log('Database initialized successfully');
    return db;
}

function saveDatabase() {
    if (db) {
        const data = db.export();
        const buffer = Buffer.from(data);
        fs.writeFileSync(dbPath, buffer);
    }
}

function getDatabase() {
    return db;
}

// Helper functions to mimic better-sqlite3 API
function prepare(sql) {
    return {
        run: (...params) => {
            db.run(sql, params);
            saveDatabase();
            return {
                changes: db.getRowsModified(),
                lastInsertRowid: getLastInsertRowId()
            };
        },
        get: (...params) => {
            const stmt = db.prepare(sql);
            stmt.bind(params);
            if (stmt.step()) {
                const row = stmt.getAsObject();
                stmt.free();
                return row;
            }
            stmt.free();
            return undefined;
        },
        all: (...params) => {
            const results = [];
            const stmt = db.prepare(sql);
            stmt.bind(params);
            while (stmt.step()) {
                results.push(stmt.getAsObject());
            }
            stmt.free();
            return results;
        }
    };
}

function getLastInsertRowId() {
    const result = db.exec("SELECT last_insert_rowid() as id");
    return result[0]?.values[0]?.[0] || 0;
}

module.exports = {
    initDatabase,
    getDatabase,
    saveDatabase,
    prepare
};
