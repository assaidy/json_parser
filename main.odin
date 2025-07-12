package main

import "core:fmt"
import "core:mem"

// TODO: add optional error logging
// TODO: allocate values on the heap
// TODO: add formated printing

main :: proc() {
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}

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
		`1234`,
		`12.0`,
		`.0`,
		`12.`, // error
		`-1`,
		`1-`, // error
		`-`, // error
		`-.1`,
		`.-1`, // error
		`1-1`, // error
		`1e10`,
		`1e+10`,
		`1e-10`,
		`1e-1-0`, // error
		`1e-1+0`, // error
		`1e+1+0`, // error
		`1e+1-0`, // error
		`1e1.0`, // error
	}

	for input in inputs {
		fmt.println("\ninput:", input)

		root, ok := parse_json_text(input)
		if !ok {
			fmt.println("invalid josn. enable debugging to show more info")
			continue
		}
		defer json_value_destroy(root)

		fmt.println(root)
	}
}
