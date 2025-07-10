package main

import "core:fmt"

main :: proc() {
	inputs := []string{``, `{}`, `{`, `[]`}
	for input in inputs {
		fmt.println("\ninput:", input)

		root, ok := parse_json(input)
		if !ok {
			fmt.println("invalid josn. enable debugging to show more info")
			continue
		}
		defer json_value_destroy(root)

		fmt.println(root)
	}
}
