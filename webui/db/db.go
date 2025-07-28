package db

import (
	"database/sql"
	"log"
	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func Init() {
	var err error
	DB, err = sql.Open("sqlite3", "./netaegis.db")
	if err != nil {
		log.Fatal(err)
	}

	_, err = DB.Exec(`
	CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY,
		username TEXT NOT NULL UNIQUE,
		password TEXT NOT NULL
	);
	`)
	if err != nil {
		log.Fatal(err)
	}
}
