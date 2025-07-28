package main

import (
    "net/http"
    "github.com/gorilla/mux"
    "netaegis/internal/auth"
)

func main() {
    r := mux.NewRouter()

    r.HandleFunc("/", auth.LoginPage).Methods("GET")
    r.HandleFunc("/login", auth.LoginHandler).Methods("POST")
    r.HandleFunc("/dashboard", auth.AuthMiddleware(auth.Dashboard)).Methods("GET")

    fs := http.FileServer(http.Dir("static"))
    r.PathPrefix("/static/").Handler(http.StripPrefix("/static/", fs))

    http.ListenAndServe(":8080", r)
}
