package main

import "core:fmt"

main :: proc() {
	inputs := []string {
		``,
		`{}`,
		`{`,
		`[]`,
		`{[]}`,
		`[{[]}]`,
		`;`,
		`true`,
		`false`,
		`null`,
		`nullx`,
		`[null, true, false, {}]`,
		`{"male": true, "info": null}`,
		`{"name": "Ahmad Assaidy", "male": true, "info": null}`,
		`"\u2713"`, // unicode code of: ✓
		`{"unicode": "\u2713"}`,
	}
	for input in inputs {
		fmt.println("\ninput:", input)

		root, ok := parse_json_string(input)
		if !ok {
			fmt.println("invalid josn. enable debugging to show more info")
			continue
		}
		defer json_value_destroy(root)

		fmt.println(root)
	}
}
