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
	current_token: JsonToken,
	peek_token:    JsonToken,
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
	if tok := me.current_token; tok.kind == .Illegal {
		fmt.println("illegal literal:", tok.value)
	}
}

parser_expect_peek :: proc(me: ^Json_Parser, kind: TokenKind) -> bool {
	if (me.peek_token.kind != kind) do return false
	parser_consume(me)
	return true
}

parser_parse_object :: proc(me: ^Json_Parser) -> (Json_Value, bool) {
	parser_consume(me) // skip the {

	entries := make([dynamic]Json_Entry, me.allocator)
	for me.current_token.kind != .RCurly && me.current_token.kind != .EOF {
		// TODO: parse (Json_Entry)s
		parser_consume(me)
	}

	if me.current_token.kind == .EOF {
		delete(entries)
		return Json_Value{}, false
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
	for me.current_token.kind != .RSquare && me.current_token.kind != .EOF {
		if value, ok := parser_parse_value(me); ok {
			append_elem(&values, value)
		} else {
			delete(values)
			return Json_Value{}, false
		}

		if !parser_expect_peek(me, .Comma) do break
	}

	if me.current_token.kind == .EOF {
		delete(values)
		return Json_Value{}, false
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
	case .LCurly:
		return parser_parse_object(me)
	case .LSquare:
		return parser_parse_array(me)
	case:
		return Json_Value{}, false
	}
}

// returns a json value that is only of kind .Object or .Array
parse_json_string :: proc(text: string, allocator := context.allocator) -> (Json_Value, bool) {
	lexer := lexer_make(text)
	parser := parser_make(lexer, allocator)
	return parser_parse_value(&parser)
}
