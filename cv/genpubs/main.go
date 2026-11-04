// Command genpubs fills the publication and report lists in cv/cv.html from
// backend/data/portfolio_seed.json, so the CV and the website share one
// source of truth. Run from the repository root:
//
//	go run cv/genpubs/main.go
package main

import (
	"encoding/json"
	"fmt"
	"html"
	"log"
	"os"
	"regexp"
	"sort"
	"strings"
)

const (
	seedPath = "backend/data/portfolio_seed.json"
	cvPath   = "cv/cv.html"
	me       = "S.L. Shrestha"
)

type publication struct {
	Title     string   `json:"title"`
	Authors   []string `json:"authors"`
	Journal   string   `json:"journal"`
	Volume    string   `json:"volume"`
	Issue     string   `json:"issue"`
	Pages     string   `json:"pages"`
	ArticleNo string   `json:"articleNo"`
	Year      int      `json:"year"`
	Month     int      `json:"month"`
	DOI       string   `json:"doi"`
}

type report struct {
	Year      int      `json:"year"`
	Authors   []string `json:"authors"`
	Title     string   `json:"title"`
	Publisher string   `json:"publisher"`
}

type seed struct {
	Profile struct {
		Reports []report `json:"reports"`
	} `json:"profile"`
	Publications []publication `json:"publications"`
}

// group labels, newest first; a publication goes in the first group whose
// lower bound it meets.
var groups = []struct {
	from  int
	label string
}{
	{2020, "2020 – 2025"},
	{2010, "2010 – 2019"},
	{0, "2001 – 2009"},
}

// authors renders an author list as a sentence, marking S.L. Shrestha.
func authors(list []string) string {
	out := make([]string, len(list))
	for i, a := range list {
		if a == me {
			out[i] = `<span class="me">` + html.EscapeString(a) + `</span>`
		} else {
			out[i] = html.EscapeString(a)
		}
	}
	line := strings.Join(out, ", ")
	// "et al." already ends the sentence; avoid "et al..".
	if strings.HasSuffix(line, ".") {
		return line
	}
	return line + "."
}

func sentence(s string) string {
	s = strings.TrimSpace(s)
	if strings.HasSuffix(s, ".") || strings.HasSuffix(s, "?") {
		return s
	}
	return s + "."
}

func pubItem(p publication) string {
	var b strings.Builder
	b.WriteString(`    <li><div>`)
	b.WriteString(authors(p.Authors))
	b.WriteString(` <span class="t">` + html.EscapeString(sentence(p.Title)) + `</span> `)
	b.WriteString(`<span class="j">` + html.EscapeString(p.Journal) + `</span>`)
	if p.Volume != "" {
		b.WriteString(", " + html.EscapeString(p.Volume))
		if p.Issue != "" {
			b.WriteString("(" + html.EscapeString(p.Issue) + ")")
		}
	}
	switch {
	case p.Pages != "":
		b.WriteString(", " + html.EscapeString(p.Pages))
	case p.ArticleNo != "":
		b.WriteString(", " + html.EscapeString(p.ArticleNo))
	}
	b.WriteString(".")
	if p.DOI != "" {
		d := html.EscapeString(p.DOI)
		b.WriteString(` <a class="doi" href="https://doi.org/` + d + `">doi:` + d + `</a>`)
	}
	year := ""
	if p.Year > 0 {
		year = fmt.Sprint(p.Year)
	}
	b.WriteString(`</div><div class="y">` + year + "</div></li>\n")
	return b.String()
}

func reportItem(r report) string {
	return fmt.Sprintf("    <li><div>%s <span class=\"t\">%s</span> %s.</div><div class=\"y\">%d</div></li>\n",
		authors(r.Authors), html.EscapeString(sentence(r.Title)), html.EscapeString(r.Publisher), r.Year)
}

func replaceBetween(doc, name, body string) string {
	re := regexp.MustCompile(`(?s)(<!-- ` + name + `:START -->\n).*?(<!-- ` + name + `:END -->)`)
	if !re.MatchString(doc) {
		log.Fatalf("markers %s:START/END not found in %s", name, cvPath)
	}
	return re.ReplaceAllLiteralString(doc, "<!-- "+name+":START -->\n"+body+"<!-- "+name+":END -->")
}

func main() {
	raw, err := os.ReadFile(seedPath)
	if err != nil {
		log.Fatal(err)
	}
	var s seed
	if err := json.Unmarshal(raw, &s); err != nil {
		log.Fatal(err)
	}

	pubs := s.Publications
	sort.SliceStable(pubs, func(i, j int) bool {
		if pubs[i].Year != pubs[j].Year {
			return pubs[i].Year > pubs[j].Year
		}
		return pubs[i].Month > pubs[j].Month
	})

	var pb strings.Builder
	current := -1
	for _, p := range pubs {
		g := len(groups) - 1
		for i, gr := range groups {
			if p.Year >= gr.from {
				g = i
				break
			}
		}
		if g != current {
			if current != -1 {
				pb.WriteString("\n")
			}
			pb.WriteString(`    <div class="yeargroup">` + groups[g].label + "</div>\n")
			current = g
		}
		pb.WriteString(pubItem(p))
	}

	var rb strings.Builder
	reports := s.Profile.Reports
	sort.SliceStable(reports, func(i, j int) bool { return reports[i].Year > reports[j].Year })
	for _, r := range reports {
		rb.WriteString(reportItem(r))
	}

	doc, err := os.ReadFile(cvPath)
	if err != nil {
		log.Fatal(err)
	}
	out := replaceBetween(string(doc), "PUBS", pb.String())
	out = replaceBetween(out, "REPORTS", rb.String())
	if err := os.WriteFile(cvPath, []byte(out), 0o644); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("cv.html: %d publications, %d reports\n", len(pubs), len(reports))
}
