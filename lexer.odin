package main

import "core:fmt"
import "core:unicode"

Token_Kind :: enum {
	EOF,
	ILLEGAL,
	ILLEGAL_UNTERMINATED_STRING,
	//
	LCURLY,
	RCURLY,
	LSQUARE,
	RSQUARE,
	//
	COMMA,
	COLON,
	//
	NULL,
	TRUE,
	FALSE,
	STRING,
}

Token_Location :: struct {
	line:   uint,
	column: uint,
}

Json_Token :: struct {
	location: Token_Location,
	kind:     Token_Kind,
	value:    string,
}

Json_Lexer :: struct {
	text:             string,
	position:         uint,
	read_position:    uint,
	current_char:     byte,
	current_location: Token_Location,
}

lexer_init :: proc(me: ^Json_Lexer, text: string) {
	me.text = text
	me.current_location = Token_Location {
		line   = 1,
		column = 0,
	}
	lexer_consume(me)
}

lexer_make :: proc(text: string) -> Json_Lexer {
	lexer: Json_Lexer
	lexer_init(&lexer, text)
	return lexer
}

lexer_consume :: proc(me: ^Json_Lexer) {
	if me.read_position >= len(me.text) {
		me.current_char = 0
		return
	}
	me.position = me.read_position
	me.read_position += 1
	me.current_char = me.text[me.position]
	if me.current_char == '\n' {
		me.current_location.line += 1
		me.current_location.column = 0
	} else {
		me.current_location.column += 1
	}
}

lexer_peek :: proc(me: ^Json_Lexer) -> byte {
	if me.read_position >= len(me.text) {
		return 0
	}
	return me.text[me.read_position]
}

lexer_skip_whitespaces :: proc(me: ^Json_Lexer) {
	for unicode.is_white_space(cast(rune)me.current_char) {
		lexer_consume(me)
	}
}

lexer_read_word :: proc(me: ^Json_Lexer) -> string {
	position := me.position
	for unicode.is_alpha(cast(rune)lexer_peek(me)) {
		lexer_consume(me)
	}
	return me.text[position:me.read_position]
}

get_token_kind_from_word :: proc(word: string) -> Token_Kind {
	switch word {
	case "null":
		return .NULL
	case "true":
		return .TRUE
	case "false":
		return .FALSE
	case:
		return .ILLEGAL
	}
}

lexer_read_string :: proc(me: ^Json_Lexer) -> (string, Token_Kind) {
	// position + 1 to skip the first "
	position := me.position + 1
	// escape sequences will be handled in the parser
	for lexer_peek(me) != '"' {
		if lexer_peek(me) == 0 {
			return "", .ILLEGAL_UNTERMINATED_STRING
		}
		lexer_consume(me)
	}
	defer lexer_consume(me)
	return me.text[position:me.read_position], .STRING

}

lexer_next_token :: proc(me: ^Json_Lexer) -> Json_Token {
	lexer_skip_whitespaces(me)
	token := Json_Token {
		location = me.current_location,
		value    = me.text[me.position:me.read_position],
	}
	switch me.current_char {
	case '{':
		token.kind = .LCURLY
	case '}':
		token.kind = .RCURLY
	case '[':
		token.kind = .LSQUARE
	case ']':
		token.kind = .RSQUARE
	case ',':
		token.kind = .COMMA
	case ':':
		token.kind = .COLON
	case 'n', 't', 'f':
		token.value = lexer_read_word(me)
		token.kind = get_token_kind_from_word(token.value)
	case '"':
		token.value, token.kind = lexer_read_string(me)
	// TODO: lex numbers
	case 0:
		token.kind = .EOF
	case:
		token.kind = .ILLEGAL
	}
	lexer_consume(me)
	return token
}
