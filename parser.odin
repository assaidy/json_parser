package main

import "core:fmt"
import "core:mem"
import "core:strings"

Value_Kind :: enum {
	Null,
	Boolean,
	Number,
	String,
	Object,
	Array,
}

Json_Entry :: struct {
	key:   string,
	value: Json_Value,
}

Json_Value :: struct {
	kind:      Value_Kind,
	variant:   union {
		bool,
		f64,
		string,
		[dynamic]Json_Entry,
		[dynamic]Json_Value,
	},
	allocator: mem.Allocator, // used in deallocation
}

json_value_destroy :: proc(me: Json_Value) {
	#partial switch val in me.variant {
	case string:
		delete(val, me.allocator)
	case [dynamic]Json_Entry:
		for e in val do json_value_destroy(e.value)
		delete(val)
	case [dynamic]Json_Value:
		for v in val do json_value_destroy(v)
		delete(val)
	}
}

Json_Parser :: struct {
	allocator:     mem.Allocator,
	lexer:         Json_Lexer,
	current_token: Json_Token,
	peek_token:    Json_Token,
}

parser_make :: proc(lexer: Json_Lexer, allocator: mem.Allocator) -> Json_Parser {
	parser := Json_Parser {
		allocator = allocator,
		lexer     = lexer,
	}
	parser_consume(&parser)
	parser_consume(&parser)
	return parser
}

parser_consume :: proc(me: ^Json_Parser) {
	me.current_token = me.peek_token
	me.peek_token = lexer_next_token(&me.lexer)
}

// TODO: might be helpfull for error checking
is_legal_token :: proc(token: Json_Token) -> bool {
	#partial switch token.kind {
	case .ILLEGAL:
	// fmt.println("illegal literal:", token.value)
	case .ILLEGAL_UNTERMINATED_STRING:
	// fmt.println("unterminated string:", token.value)
	case:
		return true
	}
	return false
}

parser_expect_peek :: proc(me: ^Json_Parser, kind: Token_Kind) -> bool {
	if (me.peek_token.kind != kind) do return false
	parser_consume(me)
	return true
}

parser_parse_object :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	parser_consume(me) // skip the {

	entries := make([dynamic]Json_Entry, me.allocator)
	for me.current_token.kind != .RCURLY {
		if me.current_token.kind == .EOF {
			delete(entries)
			return Json_Value{}, false
		}

		entry: Json_Entry
		if me.current_token.kind != .STRING {
			delete(entries)
			return Json_Value{}, false
		}
		// TODO: use a string builder and handle escape sequences
		entry.key = me.current_token.value
		if !parser_expect_peek(me, .COLON) {
			delete(entries)
			return Json_Value{}, false
		}
		parser_consume(me)
		if value, ok := parser_parse_value(me); !ok {
			delete(entries)
			return Json_Value{}, false
		} else {
			entry.value = value
		}
		append(&entries, entry)

		parser_expect_peek(me, .COMMA) // if there's an , consume it
		parser_consume(me)
	}

	json_object := Json_Value {
		kind      = .Object,
		variant   = entries,
		allocator = me.allocator,
	}
	return json_object, true
}

parser_parse_array :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	parser_consume(me) // skip the [

	values := make([dynamic]Json_Value, me.allocator)
	for me.current_token.kind != .RSQUARE {
		if me.current_token.kind == .EOF {
			delete(values)
			return Json_Value{}, false
		}

		if value, ok := parser_parse_value(me); ok {
			append(&values, value)
		} else {
			delete(values)
			return Json_Value{}, false
		}

		if parser_expect_peek(me, .COMMA) {
			parser_consume(me)
		} else {
			break
		}
	}

	json_array := Json_Value {
		kind      = .Array,
		variant   = values,
		allocator = me.allocator,
	}
	return json_array, true
}

parser_parse_value :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	#partial switch me.current_token.kind {
	case .LCURLY:
		return parser_parse_object(me)
	case .LSQUARE:
		return parser_parse_array(me)
	case .NULL:
		return Json_Value{kind = .Null}, true
	case .TRUE:
		return Json_Value{kind = .Boolean, variant = true}, true
	case .FALSE:
		return Json_Value{kind = .Boolean, variant = false}, true
	case:
		return Json_Value{}, false
	}
}

parse_json_string :: proc(text: string, allocator := context.allocator) -> (Json_Value, bool) {
	lexer := lexer_make(text)
	parser := parser_make(lexer, allocator)
	// a valid json text must have a single value.
	// that's why i only call this function once, without looping.
	return parser_parse_value(&parser)
}
