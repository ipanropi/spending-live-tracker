package main

import (
	"testing"
	"time"
)

func TestCycleStart(t *testing.T) {
	cases := []struct {
		at   time.Time
		want string // cycle start, Malaysia time
	}{
		{time.Date(2026, 11, 8, 12, 0, 0, 0, myt), "2026-11-07"},
		{time.Date(2026, 11, 7, 0, 0, 0, 0, myt), "2026-11-07"},       // payday itself starts the new cycle
		{time.Date(2026, 11, 6, 23, 59, 0, 0, myt), "2026-10-07"},     // the day before still belongs to the old one
		{time.Date(2026, 11, 6, 16, 0, 0, 0, time.UTC), "2026-11-07"}, // 16:00 UTC on the 6th is midnight on the 7th in Malaysia
		{time.Date(2027, 1, 3, 9, 0, 0, 0, myt), "2026-12-07"},        // crosses the new year
		{time.Date(2026, 3, 1, 9, 0, 0, 0, myt), "2026-02-07"},
	}
	for _, c := range cases {
		if got := cycleStart(c.at).Format("2006-01-02"); got != c.want {
			t.Errorf("cycleStart(%v) = %s, want %s", c.at, got, c.want)
		}
	}
}
