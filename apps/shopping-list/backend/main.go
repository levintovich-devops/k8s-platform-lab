package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type item struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Quantity  int       `json:"quantity"`
	CreatedAt time.Time `json:"created_at"`
}

type api struct {
	db *sql.DB
}

func main() {
	databaseURL, err := databaseURLFromEnv()
	if err != nil {
		log.Fatal(err)
	}

	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)

	if err := initializeDatabase(db); err != nil {
		log.Fatal(err)
	}

	app := &api{db: db}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", app.health)
	mux.HandleFunc("GET /api/items", app.listItems)
	mux.HandleFunc("POST /api/items", app.createItem)
	mux.HandleFunc("DELETE /api/items/{id}", app.deleteItem)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("shopping-list API listening on %s", server.Addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("serve HTTP: %v", err)
	}
}

func databaseURLFromEnv() (string, error) {
	host := envOrDefault("DB_HOST", "postgres")
	port := envOrDefault("DB_PORT", "5432")
	user := os.Getenv("POSTGRES_USER")
	password := os.Getenv("POSTGRES_PASSWORD")
	database := os.Getenv("POSTGRES_DB")
	if user == "" || password == "" || database == "" {
		return "", errors.New("POSTGRES_USER, POSTGRES_PASSWORD, and POSTGRES_DB must be set")
	}
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		host, port, quoteConnValue(user), quoteConnValue(password), quoteConnValue(database),
	), nil
}

func quoteConnValue(value string) string {
	return "'" + strings.NewReplacer(`\`, `\\`, `'`, `\'`).Replace(value) + "'"
}

func envOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

func initializeDatabase(db *sql.DB) error {
	const schema = `
		CREATE TABLE IF NOT EXISTS shopping_items (
			id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
			name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 120),
			quantity INTEGER NOT NULL CHECK (quantity BETWEEN 1 AND 100000),
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`

	deadline := time.Now().Add(5 * time.Minute)
	for {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		err := db.PingContext(ctx)
		if err == nil {
			_, err = db.ExecContext(ctx, schema)
		}
		cancel()
		if err == nil {
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("initialize database: %w", err)
		}
		log.Printf("database is not ready yet: %v", err)
		time.Sleep(5 * time.Second)
	}
}

func (a *api) health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := a.db.PingContext(ctx); err != nil {
		http.Error(w, "database unavailable", http.StatusServiceUnavailable)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *api) listItems(w http.ResponseWriter, r *http.Request) {
	rows, err := a.db.QueryContext(r.Context(),
		"SELECT id, name, quantity, created_at FROM shopping_items ORDER BY id")
	if err != nil {
		http.Error(w, "could not load items", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	items := make([]item, 0)
	for rows.Next() {
		var current item
		if err := rows.Scan(&current.ID, &current.Name, &current.Quantity, &current.CreatedAt); err != nil {
			http.Error(w, "could not load items", http.StatusInternalServerError)
			return
		}
		items = append(items, current)
	}
	if err := rows.Err(); err != nil {
		http.Error(w, "could not load items", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, items)
}

func (a *api) createItem(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	var input struct {
		Name     string `json:"name"`
		Quantity int    `json:"quantity"`
	}
	if err := decoder.Decode(&input); err != nil {
		http.Error(w, "provide a JSON name and quantity", http.StatusBadRequest)
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		http.Error(w, "request must contain one JSON object", http.StatusBadRequest)
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if input.Name == "" || utf8.RuneCountInString(input.Name) > 120 || input.Quantity < 1 || input.Quantity > 100000 {
		http.Error(w, "name must be 1-120 characters and quantity must be 1-100000", http.StatusBadRequest)
		return
	}

	var created item
	err := a.db.QueryRowContext(r.Context(),
		"INSERT INTO shopping_items (name, quantity) VALUES ($1, $2) RETURNING id, name, quantity, created_at",
		input.Name, input.Quantity,
	).Scan(&created.ID, &created.Name, &created.Quantity, &created.CreatedAt)
	if err != nil {
		http.Error(w, "could not save item", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, created)
}

func (a *api) deleteItem(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id < 1 {
		http.Error(w, "item id must be a positive integer", http.StatusBadRequest)
		return
	}
	result, err := a.db.ExecContext(r.Context(), "DELETE FROM shopping_items WHERE id = $1", id)
	if err != nil {
		http.Error(w, "could not delete item", http.StatusInternalServerError)
		return
	}
	count, err := result.RowsAffected()
	if err != nil {
		http.Error(w, "could not delete item", http.StatusInternalServerError)
		return
	}
	if count == 0 {
		http.Error(w, "item not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("write JSON response: %v", err)
	}
}
