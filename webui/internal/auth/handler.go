package auth

import (
    "html/template"
    "net/http"
)

var tmpl = template.Must(template.ParseGlob("templates/*.html"))

func LoginPage(w http.ResponseWriter, r *http.Request) {
    tmpl.ExecuteTemplate(w, "login.html", nil)
}

func LoginHandler(w http.ResponseWriter, r *http.Request) {
    r.ParseForm()
    username := r.FormValue("username")
    password := r.FormValue("password")

    if username == "admin" && password == "password" {
        http.SetCookie(w, &http.Cookie{
            Name:  "session",
            Value: "authenticated",
            Path:  "/",
        })
        http.Redirect(w, r, "/dashboard", http.StatusSeeOther)
    } else {
        tmpl.ExecuteTemplate(w, "login.html", "Invalid credentials")
    }
}

func Dashboard(w http.ResponseWriter, r *http.Request) {
    tmpl.ExecuteTemplate(w, "dashboard.html", nil)
}
