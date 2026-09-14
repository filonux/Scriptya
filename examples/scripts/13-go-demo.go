// MENU: Demo — Go
// DESCRIPTION: Go example compiled and run by Scriptya
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 130
// ASK: Demo value
// ICON: ../assets/demo-blue.svg

package main

import (
	"fmt"
	"os"
)

func main() {
	value := "demo"
	if len(os.Args) > 1 {
		value = os.Args[1]
	}
	fmt.Printf("GO_DEMO_OK|%s\n", value)
}
