package auth

import (
    "net/http"
)

func AuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        cookie, err := r.Cookie("session")
        if err != nil || cookie.Value != "authenticated" {
            http.Redirect(w, r, "/", http.StatusSeeOther)
            return
        }
        next.ServeHTTP(w, r)
    }
}
