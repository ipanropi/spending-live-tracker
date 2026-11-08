// Spending Tracker: a small app that reads your Wise MYR transactions and shows a dashboard.
//
// Laptop mode (the default): double-click to run. It opens in your browser, and only this computer can reach it.
// The first time, it asks for your Wise API token and saves it in wise_token.txt next to the app.
//
// Hosted mode (when PORT is set, as hosts like Render and Cloud Run do): it serves the dashboard to any device,
// behind a password. Set WISE_TOKEN and APP_PASSWORD in the host's environment variables.
package main

import (
	"bufio"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
)

//go:embed web
var webFS embed.FS

var wiseAPI = "https://api.wise.com"

// Malaysia time (no daylight saving). Hosts run on UTC, so cycle dates are worked out in MYT explicitly.
var myt = time.FixedZone("MYT", 8*60*60)

// Days of the month you get paid and top up Wise. "Left" on the dashboard counts down to the next one.
var paydays = []int{7, 22}

const (
	currency     = "MYR"
	payDay       = 7 // the monthly summary cycle runs from the 7th to the 6th
	cyclesToLoad = 6
	localAddr    = "127.0.0.1:8765" // laptop mode: only reachable from this computer
	localURL     = "http://localhost:8765"

	minPasswordLen = 12
	sessionCookie  = "st_session"
	rememberFor    = 30 * 24 * time.Hour // "Keep me logged in" ticked
	sessionFor     = 12 * time.Hour      // not ticked: also forgotten when the browser closes
	maxLoginFails  = 20                  // wrong passwords allowed per failWindow, across everyone
	failWindow     = 15 * time.Minute
)

// Your categories. First match wins, so specific words (grabfood) sit above general ones (grab).
// Add merchant names here whenever something lands in "Other", then rebuild.
var categories = []struct {
	Name  string
	Words []string
}{
	{"Food & Drinks", []string{"grabfood", "foodpanda", "shopeefood", "restaurant", "restoran", "cafe", "kopitiam",
		"mamak", "nasi", "mcdonald", "kfc", "starbucks", "zus", "tealive", "subway", "domino", "pizza", "bakery",
		"texas chicken"}},
	{"Groceries", []string{"99 speedmart", "mydin", "lotus", "aeon", "jaya grocer", "giant", "econsave",
		"village grocer", "7-eleven", "7 eleven", "family mart", "familymart", "kk mart"}},
	{"Transport", []string{"grab", "petronas", "shell", "petron", "caltex", "bhpetrol", "touch n go", "parking",
		"rapid", "mrt", "lrt", "ktm", "airasia", "toll"}},
	{"Shopping", []string{"shopee", "lazada", "tiktok shop", "uniqlo", "ikea", "mr diy", "mr. diy", "decathlon",
		"watsons", "guardian"}},
	{"Bills", []string{"tnb", "tenaga", "unifi", "maxis", "celcom", "u mobile", "yes 4g", "time dotcom", "astro",
		"indah water", "air selangor"}},
	{"Entertainment", []string{"netflix", "spotify", "youtube", "disney", "gsc", "tgv", "mbo", "steam",
		"playstation", "roblox"}},
}

type transaction struct {
	Date     string  `json:"date"`
	Amount   float64 `json:"amount"` // negative = money out
	Name     string  `json:"name"`
	Category string  `json:"category"`
	Note     string  `json:"note"`
}

type payload struct {
	Tx        []transaction `json:"tx"`
	Balance   *float64      `json:"balance"`
	Updated   string        `json:"updated"`
	CycleDay  int           `json:"cycleDay"`
	Paydays   []int         `json:"paydays"`
	CanLogout bool          `json:"canLogout"`
}

var (
	token       string
	appPassword string
	serverMode  bool // hosted mode: listen on PORT for any device, behind a login
	sessionKey  []byte
	client      = &http.Client{Timeout: 30 * time.Second}
	idsMu       sync.Mutex
	profileID   string
	balanceID   string
	errNoToken  = errors.New("no token entered")
	loginMu     sync.Mutex
	loginFails  []time.Time
	indexHTML   = mustRead("web/index.html")
	loginHTML   = string(mustRead("web/login.html"))
)

// Pages anyone can load without logging in. The manifest and icons must be public for "Add to Home screen".
var publicPaths = map[string]bool{
	"/login": true, "/logout": true, "/manifest.webmanifest": true,
	"/icon-192.png": true, "/icon-512.png": true, "/apple-touch-icon.png": true,
}

func main() {
	port := strings.TrimSpace(os.Getenv("PORT"))
	serverMode = port != ""

	var ln net.Listener
	var err error
	if serverMode {
		token = strings.TrimSpace(os.Getenv("WISE_TOKEN"))
		appPassword = os.Getenv("APP_PASSWORD")
		if token == "" {
			fail("WISE_TOKEN is not set. Add your Wise API token to the host's environment variables.")
		}
		if len(appPassword) < minPasswordLen {
			fail(fmt.Sprintf("APP_PASSWORD must be set and at least %d characters long.", minPasswordLen))
		}
		if ln, err = net.Listen("tcp", ":"+port); err != nil {
			fail(err.Error())
		}
	} else {
		if ln, err = net.Listen("tcp", localAddr); err != nil {
			fmt.Println("Spending Tracker is already running. Opening it in your browser.")
			openBrowser(localURL)
			return
		}
		if token, err = loadToken(); err != nil {
			fail(err.Error())
		}
	}
	// Login cookies are signed with a key only the server knows. Changing the token or password logs everyone out.
	key := sha256.Sum256([]byte("spending-tracker session v1\x00" + token + "\x00" + appPassword))
	sessionKey = key[:]

	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-store")
		w.Write(indexHTML)
	})
	mux.HandleFunc("GET /api/data", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		data, err := getData()
		if err != nil {
			writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
			return
		}
		data.CanLogout = serverMode
		writeJSON(w, http.StatusOK, data)
	})
	mux.HandleFunc("GET /manifest.webmanifest", serveFile("web/manifest.webmanifest", "application/manifest+json"))
	mux.HandleFunc("GET /icon-192.png", serveFile("web/icon-192.png", "image/png"))
	mux.HandleFunc("GET /icon-512.png", serveFile("web/icon-512.png", "image/png"))
	mux.HandleFunc("GET /apple-touch-icon.png", serveFile("web/icon-180.png", "image/png"))
	if serverMode {
		mux.HandleFunc("GET /login", showLogin)
		mux.HandleFunc("POST /login", login)
		mux.HandleFunc("POST /logout", logout)
	}

	srv := &http.Server{Handler: protect(mux), ReadHeaderTimeout: 10 * time.Second}
	if serverMode {
		fmt.Println("Spending Tracker is running on port " + port)
	} else {
		fmt.Println("Spending Tracker is running at " + localURL)
		fmt.Println("Keep this window open while you use it. Close it to stop.")
		go func() {
			time.Sleep(300 * time.Millisecond)
			openBrowser(localURL)
		}()
	}
	if err := srv.Serve(ln); err != nil {
		fail(err.Error())
	}
}

// protect adds safety headers, and in hosted mode sends anyone without a valid login to /login.
func protect(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h := w.Header()
		h.Set("X-Content-Type-Options", "nosniff")
		h.Set("X-Frame-Options", "DENY")
		h.Set("Referrer-Policy", "no-referrer")
		if !serverMode || publicPaths[r.URL.Path] || validSession(r) {
			next.ServeHTTP(w, r)
			return
		}
		if strings.HasPrefix(r.URL.Path, "/api/") {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "You're logged out. Reload the page to log in."})
			return
		}
		http.Redirect(w, r, "/login", http.StatusSeeOther)
	})
}

func showLogin(w http.ResponseWriter, r *http.Request) {
	if validSession(r) {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}
	renderLogin(w, http.StatusOK, "")
}

func login(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	if err := r.ParseForm(); err != nil {
		renderLogin(w, http.StatusBadRequest, "Something went wrong. Try again.")
		return
	}
	if tooManyFails() {
		renderLogin(w, http.StatusTooManyRequests, "Too many wrong passwords. Wait 15 minutes and try again.")
		return
	}
	if !passwordOK(r.PostFormValue("password")) {
		recordFail()
		time.Sleep(time.Second)
		renderLogin(w, http.StatusUnauthorized, "Wrong password.")
		return
	}
	c := &http.Cookie{Name: sessionCookie, Path: "/", HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode}
	if r.PostFormValue("remember") != "" {
		c.Value = signSession(time.Now().Add(rememberFor))
		c.MaxAge = int(rememberFor.Seconds())
	} else {
		c.Value = signSession(time.Now().Add(sessionFor)) // no MaxAge, so the browser drops it when closed
	}
	http.SetCookie(w, c)
	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func logout(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{Name: sessionCookie, Path: "/", MaxAge: -1, HttpOnly: true, Secure: true,
		SameSite: http.SameSiteLaxMode})
	http.Redirect(w, r, "/login", http.StatusSeeOther)
}

// renderLogin shows the login page. msg is always one of our own fixed messages, never user input.
func renderLogin(w http.ResponseWriter, status int, msg string) {
	page := loginHTML
	if msg != "" {
		page = strings.Replace(page, "<!--ERROR-->", `<div class="error">`+msg+`</div>`, 1)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	io.WriteString(w, page)
}

func passwordOK(p string) bool {
	a, b := sha256.Sum256([]byte(p)), sha256.Sum256([]byte(appPassword))
	return subtle.ConstantTimeCompare(a[:], b[:]) == 1
}

// A session cookie is "<expiry unix time>.<HMAC of it>", so the server keeps no state and survives restarts.
func signSession(exp time.Time) string {
	e := strconv.FormatInt(exp.Unix(), 10)
	return e + "." + hex.EncodeToString(sessionMAC(e))
}

func validSession(r *http.Request) bool {
	c, err := r.Cookie(sessionCookie)
	if err != nil {
		return false
	}
	e, sig, ok := strings.Cut(c.Value, ".")
	if !ok {
		return false
	}
	exp, err := strconv.ParseInt(e, 10, 64)
	if err != nil || time.Now().Unix() > exp {
		return false
	}
	got, err := hex.DecodeString(sig)
	return err == nil && hmac.Equal(got, sessionMAC(e))
}

func sessionMAC(s string) []byte {
	m := hmac.New(sha256.New, sessionKey)
	m.Write([]byte(s))
	return m.Sum(nil)
}

// tooManyFails caps wrong passwords across everyone, so the password can't be guessed by brute force.
func tooManyFails() bool {
	loginMu.Lock()
	defer loginMu.Unlock()
	cutoff := time.Now().Add(-failWindow)
	kept := loginFails[:0]
	for _, t := range loginFails {
		if t.After(cutoff) {
			kept = append(kept, t)
		}
	}
	loginFails = kept
	return len(loginFails) >= maxLoginFails
}

func recordFail() {
	loginMu.Lock()
	loginFails = append(loginFails, time.Now())
	loginMu.Unlock()
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func serveFile(name, contentType string) http.HandlerFunc {
	b := mustRead(name)
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", contentType)
		w.Header().Set("Cache-Control", "public, max-age=86400")
		w.Write(b)
	}
}

func mustRead(name string) []byte {
	b, err := webFS.ReadFile(name)
	if err != nil {
		panic(err)
	}
	return b
}

func getData() (*payload, error) {
	pid, bid, err := getIDs()
	if err != nil {
		return nil, err
	}

	now := time.Now()
	start := cycleStart(now).AddDate(0, -(cyclesToLoad - 1), 0)
	q := url.Values{}
	q.Set("currency", currency)
	q.Set("type", "COMPACT")
	q.Set("intervalStart", start.UTC().Format("2006-01-02T15:04:05.000Z"))
	q.Set("intervalEnd", now.UTC().Format("2006-01-02T15:04:05.000Z"))

	var st map[string]any
	path := "/v1/profiles/" + pid + "/balance-statements/" + bid + "/statement.json?" + q.Encode()
	if err := wiseGet(path, &st); err != nil {
		return nil, err
	}

	out := &payload{Tx: []transaction{}, Updated: now.UTC().Format(time.RFC3339), CycleDay: payDay, Paydays: paydays}
	list, _ := st["transactions"].([]any)
	for _, item := range list {
		t := obj(item)
		d := obj(t["details"])
		merchant := obj(d["merchant"])

		amount := num(obj(t["amount"])["value"])
		if str(t["type"]) == "DEBIT" && amount > 0 {
			amount = -amount // money out is always negative
		}
		if str(t["type"]) == "CREDIT" && amount < 0 {
			amount = -amount // money in is always positive
		}

		name := firstNonEmpty(str(merchant["name"]), str(obj(d["recipient"])["name"]), str(d["senderName"]),
			str(d["description"]), "Unknown")
		name = strings.TrimSpace(name)

		out.Tx = append(out.Tx, transaction{
			Date:     str(t["date"]),
			Amount:   amount,
			Name:     name,
			Category: categorize(name, str(merchant["category"]), str(d["type"]), amount),
			Note:     str(d["description"]),
		})
	}

	if b := obj(st["endOfStatementBalance"]); b != nil {
		v := num(b["value"])
		out.Balance = &v
	}
	return out, nil
}

// cycleStart returns the start of the pay cycle containing t: the latest payday at midnight, Malaysia time.
func cycleStart(t time.Time) time.Time {
	t = t.In(myt)
	s := time.Date(t.Year(), t.Month(), payDay, 0, 0, 0, 0, myt)
	if t.Before(s) {
		s = s.AddDate(0, -1, 0)
	}
	return s
}

// getIDs finds your personal profile and MYR balance once, then remembers them.
func getIDs() (string, string, error) {
	idsMu.Lock()
	defer idsMu.Unlock()
	if profileID != "" && balanceID != "" {
		return profileID, balanceID, nil
	}

	var profiles []any
	if err := wiseGet("/v2/profiles", &profiles); err != nil {
		return "", "", err
	}
	var personal map[string]any
	for _, p := range profiles {
		if strings.EqualFold(str(obj(p)["type"]), "PERSONAL") {
			personal = obj(p)
			break
		}
	}
	if personal == nil && len(profiles) > 0 {
		personal = obj(profiles[0])
	}
	if personal == nil {
		return "", "", errors.New("No Wise profile found for this token.")
	}
	pid := idString(personal["id"])

	var balances []any
	if err := wiseGet("/v4/profiles/"+pid+"/balances?types=STANDARD", &balances); err != nil {
		return "", "", err
	}
	for _, b := range balances {
		if str(obj(b)["currency"]) == currency {
			profileID, balanceID = pid, idString(obj(b)["id"])
			return profileID, balanceID, nil
		}
	}
	return "", "", fmt.Errorf("No %s balance found in your Wise account. Add some %s first.", currency, currency)
}

func categorize(name, wiseCategory, detailType string, amount float64) string {
	if amount > 0 {
		return "Money in"
	}
	text := strings.ToLower(name)
	for _, c := range categories {
		for _, w := range c.Words {
			if strings.Contains(text, w) {
				return c.Name
			}
		}
	}
	switch {
	case wiseCategory != "":
		return wiseCategory
	case detailType == "TRANSFER":
		return "Transfers"
	case detailType == "CONVERSION":
		return "Currency exchange"
	}
	return "Other"
}

func wiseGet(path string, out any) error {
	req, err := http.NewRequest("GET", wiseAPI+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := client.Do(req)
	if err != nil {
		return errors.New("Could not reach Wise. Check your internet connection.")
	}
	defer resp.Body.Close()

	switch resp.StatusCode {
	case http.StatusOK:
		dec := json.NewDecoder(resp.Body)
		dec.UseNumber() // keeps long IDs exact
		return dec.Decode(out)
	case http.StatusUnauthorized:
		if serverMode {
			return errors.New("Wise rejected the token. Put a new token in WISE_TOKEN on the host.")
		}
		return errors.New("Wise rejected the token. Delete wise_token.txt next to the app and open it again with a new token.")
	case http.StatusForbidden:
		return errors.New("Wise blocked this request (403). The token may not have statement access, or Wise wants extra verification. Send Claude this message.")
	default:
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 300))
		return fmt.Errorf("Wise API error %d: %s", resp.StatusCode, body)
	}
}

func loadToken() (string, error) {
	if t := strings.TrimSpace(os.Getenv("WISE_TOKEN")); t != "" {
		return t, nil
	}
	path := tokenPath()
	if b, err := os.ReadFile(path); err == nil {
		if t := strings.TrimSpace(string(b)); t != "" {
			return t, nil
		}
	}
	fmt.Print("Paste your Wise API token (read only) and press Enter: ")
	line, _ := bufio.NewReader(os.Stdin).ReadString('\n')
	t := strings.TrimSpace(line)
	if t == "" {
		return "", errNoToken
	}
	if err := os.WriteFile(path, []byte(t), 0600); err != nil {
		fmt.Println("Could not save the token, so you'll be asked again next time:", err)
	} else {
		fmt.Println("Saved in wise_token.txt next to this app. Delete it if you ever need to change the token.")
	}
	return t, nil
}

func tokenPath() string {
	exe, err := os.Executable()
	if err != nil {
		return "wise_token.txt"
	}
	return filepath.Join(filepath.Dir(exe), "wise_token.txt")
}

func openBrowser(u string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", u)
	case "darwin":
		cmd = exec.Command("open", u)
	default:
		cmd = exec.Command("xdg-open", u)
	}
	_ = cmd.Start()
}

func fail(msg string) {
	fmt.Println("\n" + msg)
	if !serverMode { // keep the laptop window open so the message can be read
		fmt.Print("Press Enter to close.")
		bufio.NewReader(os.Stdin).ReadString('\n')
	}
	os.Exit(1)
}

// Small helpers for reading Wise's JSON safely.
func obj(v any) map[string]any { m, _ := v.(map[string]any); return m }

func str(v any) string { s, _ := v.(string); return s }

func num(v any) float64 {
	switch n := v.(type) {
	case json.Number:
		f, _ := n.Float64()
		return f
	case float64:
		return n
	case string:
		f, _ := strconv.ParseFloat(n, 64)
		return f
	}
	return 0
}

func idString(v any) string {
	switch n := v.(type) {
	case json.Number:
		return n.String()
	case string:
		return n
	case float64:
		return strconv.FormatFloat(n, 'f', -1, 64)
	}
	return ""
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
