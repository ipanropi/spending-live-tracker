// Spending Tracker: a small app that reads your Wise MYR transactions and shows a dashboard.
// Double-click to run. It opens in your browser. Close the window to stop it.
// The first time, it asks for your Wise API token and saves it in wise_token.txt next to the app.
package main

import (
	"bufio"
	_ "embed"
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

//go:embed index.html
var indexHTML []byte

var wiseAPI = "https://api.wise.com"

const (
	currency     = "MYR"
	monthsToLoad = 6
	listenAddr   = "127.0.0.1:8765" // only reachable from this computer
	appURL       = "http://localhost:8765"
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
	Tx      []transaction `json:"tx"`
	Balance *float64      `json:"balance"`
	Updated string        `json:"updated"`
}

var (
	token      string
	client     = &http.Client{Timeout: 30 * time.Second}
	idsMu      sync.Mutex
	profileID  string
	balanceID  string
	errNoToken = errors.New("no token entered")
)

func main() {
	ln, err := net.Listen("tcp", listenAddr)
	if err != nil {
		fmt.Println("Spending Tracker is already running. Opening it in your browser.")
		openBrowser(appURL)
		return
	}

	token, err = loadToken()
	if err != nil {
		fail(err.Error())
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Write(indexHTML)
	})
	mux.HandleFunc("/api/data", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		data, err := getData()
		if err != nil {
			w.WriteHeader(http.StatusBadGateway)
			json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
			return
		}
		json.NewEncoder(w).Encode(data)
	})

	fmt.Println("Spending Tracker is running at " + appURL)
	fmt.Println("Keep this window open while you use it. Close it to stop.")
	go func() {
		time.Sleep(300 * time.Millisecond)
		openBrowser(appURL)
	}()
	if err := http.Serve(ln, mux); err != nil {
		fail(err.Error())
	}
}

func getData() (*payload, error) {
	pid, bid, err := getIDs()
	if err != nil {
		return nil, err
	}

	now := time.Now()
	start := time.Date(now.Year(), now.Month()-(monthsToLoad-1), 1, 0, 0, 0, 0, time.Local)
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

	out := &payload{Tx: []transaction{}, Updated: now.UTC().Format(time.RFC3339)}
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
	fmt.Print("Press Enter to close.")
	bufio.NewReader(os.Stdin).ReadString('\n')
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
