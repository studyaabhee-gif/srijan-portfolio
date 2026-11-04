// Package data embeds the canonical portfolio seed so the binary works with
// zero external setup. An on-disk copy (DATA_DIR/portfolio_seed.json) takes
// precedence at runtime, so content can be edited without rebuilding.
package data

import _ "embed"

//go:embed portfolio_seed.json
var Seed []byte
