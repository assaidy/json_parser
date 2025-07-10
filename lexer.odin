package main

import "core:unicode"

TokenKind :: enum {
	EOF,
	Illegal,
	//
	LCurly,
	RCurly,
}

TokenLocation :: struct {
	line:   uint,
	column: uint,
}

JsonToken :: struct {
	location: TokenLocation,
	kind:     TokenKind,
	value:    string,
}

Json_Lexer :: struct {
	text:             string,
	position:         uint,
	read_position:    uint,
	current_char:     byte,
	current_location: TokenLocation,
}

lexer_init :: proc(me: ^Json_Lexer, text: string) {
	me.text = text
	me.current_location = TokenLocation {
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

lexer_next_token :: proc(me: ^Json_Lexer) -> JsonToken {
	lexer_skip_whitespaces(me)
	token := JsonToken {
		location = me.current_location,
		value    = me.text[me.position:me.read_position],
	}
	switch me.current_char {
	case '{':
		token.kind = .LCurly
	case '}':
		token.kind = .RCurly
	case 0:
		token.kind = .EOF
	case:
		token.kind = .Illegal
	}
	lexer_consume(me)
	return token
}
