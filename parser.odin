package main

import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"

Value_Kind :: enum {
	VALUE_NULL,
	VALUE_BOOLEAN,
	VALUE_NUMBER,
	VALUE_STRING,
	VALUE_OBJECT,
	VALUE_ARRAY,
}

Json_String :: struct {
	allocator: mem.Allocator,
	value:     string,
}

Json_Entry :: struct {
	key:   Json_String,
	value: Json_Value,
}

json_entry_destroy :: proc(entry: Json_Entry) {
	delete(entry.key.value, entry.key.allocator)
	json_value_destroy(entry.value)
}

Json_Value :: struct {
	kind:      Value_Kind,
	variant:   union {
		bool,
		f64,
		Json_String,
		[dynamic]Json_Entry,
		[dynamic]Json_Value,
	},
	allocator: mem.Allocator, // used in deallocation
}

json_value_destroy :: proc(me: Json_Value) {
	#partial switch val in me.variant {
	case Json_String:
		delete(val.value, val.allocator)
	case [dynamic]Json_Entry:
		for e in val do json_entry_destroy(e)
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
		if json_string, ok := get_json_string(me.current_token.value, me.allocator); !ok {
			delete(entries)
			return Json_Value{}, false
		} else {
			entry.key = json_string
		}
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

		parser_expect_peek(me, .COMMA) // if there's a ',' consume it
		parser_consume(me)
	}

	json_object := Json_Value {
		kind      = .VALUE_OBJECT,
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

	return Json_Value{kind = .VALUE_ARRAY, variant = values, allocator = me.allocator}, true
}

parser_parse_string :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	json_string, ok := get_json_string(me.current_token.value, me.allocator)
	if !ok {
		return Json_Value{}, false
	}
	return Json_Value{kind = .VALUE_STRING, variant = json_string}, true
}

get_json_string :: proc(s: string, allocator: mem.Allocator) -> (Json_String, bool) {
	builder := strings.builder_make(allocator)
	for i := 0; i < len(s); i += 1 {
		if s[i] != '\\' {
			strings.write_byte(&builder, s[i])
		} else {
			if i + 1 < len(s) {
				i += 1
				switch s[i] {
				case '"':
					strings.write_byte(&builder, '"')
				case '\\':
					strings.write_byte(&builder, '\\')
				case '/':
					strings.write_byte(&builder, '/')
				case 'b':
					strings.write_byte(&builder, '\b')
				case 'f':
					strings.write_byte(&builder, '\f')
				case 'n':
					strings.write_byte(&builder, '\n')
				case 'r':
					strings.write_byte(&builder, '\r')
				case 't':
					strings.write_byte(&builder, '\t')
				case 'u':
					i += 1
					if i + 4 > len(s) {
						return Json_String{}, false
					}
					// parse the 4 hex digits
					if n, ok := strconv.parse_int(s[i:i + 4], 16); !ok {
						return Json_String{}, false
					} else {
						strings.write_rune(&builder, rune(n))
					}
					i += 3
				case:
					return Json_String{}, false
				}
			} else {
				return Json_String{}, false
			}
		}
	}
	return Json_String{value = strings.to_string(builder), allocator = allocator}, true
}

parser_parse_number :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	json_number, ok := strconv.parse_f64(me.current_token.value)
	if !ok {
		return Json_Value{}, false
	}
	return Json_Value{kind = .VALUE_NUMBER, variant = json_number}, true
}

parser_parse_value :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	#partial switch me.current_token.kind {
	case .LCURLY:
		return parser_parse_object(me)
	case .LSQUARE:
		return parser_parse_array(me)
	case .NULL:
		return Json_Value{kind = .VALUE_NULL}, true
	case .TRUE:
		return Json_Value{kind = .VALUE_BOOLEAN, variant = true}, true
	case .FALSE:
		return Json_Value{kind = .VALUE_BOOLEAN, variant = false}, true
	case .STRING:
		return parser_parse_string(me)
	case .NUMBER:
		return parser_parse_number(me)
	case:
		return Json_Value{}, false
	}
}

parse_json_text :: proc(text: string, allocator := context.allocator) -> (Json_Value, bool) {
	lexer := lexer_make(text)
	parser := parser_make(lexer, allocator)
	// a valid json text must have a single value.
	// that's why i only call this function once, without looping.
	return parser_parse_value(&parser)
}
