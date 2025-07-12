package main

import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"

Null :: distinct rawptr
Boolean :: bool
Number :: f64
String :: string
Object :: distinct map[string]Json_Value
Array :: distinct [dynamic]Json_Value

Json_Value :: union {
	Null,
	Boolean,
	Number,
	String,
	Object,
	Array,
}

json_value_destroy :: proc(me: Json_Value, allocator := context.allocator) {
	context.allocator = allocator
	#partial switch value in me {
	case String:
		delete(value)
	case Object:
		for k, v in value {
			delete(k)
			json_value_destroy(v)
		}
		delete(value)
	case Array:
		for v in value do json_value_destroy(v)
		delete(value)
	}
}

Error :: enum {
	None,
	Empty_Text,
	Unexpected_Token,
	Invalid_Escape_Sequence,
	Unterminated_Object,
	Missing_Object_Key,
	Missing_Colon_After_Key,
	Duplicate_Object_Key,
	Invalid_Json_Literal,
	Unterminated_String,
	Unterminated_Array,
	Invalid_Number,
	Many_Values_In_Text,
}

Json_Parser :: struct {
	allocator:     mem.Allocator,
	lexer:         Json_Lexer,
	current_token: Json_Token,
	peek_token:    Json_Token,
}

parser_make :: proc(
	lexer: Json_Lexer,
	allocator: mem.Allocator,
) -> (
	res: Json_Parser,
	err: Error,
) {
	parser := Json_Parser {
		allocator = allocator,
		lexer     = lexer,
	}
	parser_consume(&parser) or_return
	parser_consume(&parser) or_return
	return parser, nil
}

parser_consume :: proc(me: ^Json_Parser) -> Error {
	me.current_token = me.peek_token
	me.peek_token = lexer_next_token(&me.lexer)
	return is_legal_token(me.current_token)
}

is_legal_token :: proc(token: Json_Token) -> Error {
	#partial switch token.kind {
	case .ILLEGAL_LITERAL:
		return .Invalid_Json_Literal
	case .ILLEGAL_UNTERMINATED_STRING:
		return .Unterminated_String
	case .ILLEGAL_NUMBER:
		return .Invalid_Number
	}
	return nil
}

parser_expect_peek :: proc(me: ^Json_Parser, kind: Token_Kind) -> (res: bool, err: Error) {
	if (me.peek_token.kind != kind) do return false, nil
	parser_consume(me) or_return
	return true, nil
}

parser_parse_object :: proc(me: ^Json_Parser) -> (res: Json_Value, err: Error) {
	parser_consume(me) // skip the {

	object := make(Object, me.allocator)
	defer if err != nil {
		delete(object)
	}
	for me.current_token.kind != .RCURLY {
		if me.current_token.kind == .EOF {
			err = .Unterminated_Object;return
		}
		if me.current_token.kind != .STRING {
			err = .Missing_Object_Key;return
		}
		key := get_json_string(me.current_token.value, me.allocator) or_return
		if key in object {
			err = .Duplicate_Object_Key;return
		}
		ok := parser_expect_peek(me, .COLON) or_return
		if !ok {
			err = .Missing_Colon_After_Key;return
		}
		parser_consume(me)
		value := parser_parse_value(me) or_return
		object[key] = value

		parser_expect_peek(me, .COMMA) // if there's a ',' consume it
		parser_consume(me)
	}
	return object, nil
}

parser_parse_array :: proc(me: ^Json_Parser) -> (res: Json_Value, err: Error) {
	parser_consume(me) // skip the [

	array := make(Array, me.allocator)
	defer if err != nil {
		delete(array)
	}
	for me.current_token.kind != .RSQUARE {
		if me.current_token.kind == .EOF {
			err = .Unterminated_Array;return
		}
		value := parser_parse_value(me) or_return
		append(&array, value)
		ok := parser_expect_peek(me, .COMMA) or_return
		if ok {
			parser_consume(me) or_return
		} else {
			break
		}
	}
	return array, nil
}

parser_parse_string :: proc(me: ^Json_Parser) -> (res: Json_Value, err: Error) {
	s := get_json_string(me.current_token.value, me.allocator) or_return
	res = String(s)
	return
}

get_json_string :: proc(s: string, allocator: mem.Allocator) -> (res: string, err: Error) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
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
						err = .Invalid_Escape_Sequence;return
					}
					// parse the 4 hex digits
					if n, ok := strconv.parse_int(s[i:i + 4], 16); !ok {
						err = .Invalid_Escape_Sequence;return
					} else {
						strings.write_rune(&builder, rune(n))
					}
					i += 3
				case:
					err = .Invalid_Escape_Sequence;return
				}
			} else {
				err = .Invalid_Escape_Sequence;return
			}
		}
	}
	res = String(strings.clone(strings.to_string(builder), allocator))
	return
}

parser_parse_value :: proc(me: ^Json_Parser) -> (res: Json_Value, err: Error) {
	#partial switch me.current_token.kind {
	case .NULL:
		res = Null{}
	case .TRUE:
		res = Boolean(true)
	case .FALSE:
		res = Boolean(false)
	case .NUMBER:
		number, _ := strconv.parse_f64(me.current_token.value)
		res = Number(number)
	case .STRING:
		res, err = parser_parse_string(me)
	case .LCURLY:
		res, err = parser_parse_object(me)
	case .LSQUARE:
		res, err = parser_parse_array(me)
	case .EOF:
		err = .Empty_Text
	case:
		err = .Unexpected_Token
	}
	// a valid json text must have a single value
	parser_consume(me) or_return
	if me.current_token.kind != .EOF do err = .Many_Values_In_Text
	return
}

parse_json_text :: proc(
	text: string,
	allocator := context.allocator,
) -> (
	res: Json_Value,
	err: Error,
) {
	lexer := lexer_make(text)
	parser := parser_make(lexer, allocator) or_return
	return parser_parse_value(&parser)
}
