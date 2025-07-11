package main

import "core:unicode"

Token_Kind :: enum {
	EOF,
	Illegal,
	//
	LCurly,
	RCurly,
	LSquare,
	RSquare,
	//
	Comma,
	//
	Null,
	True,
	False,
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
		return .Null
	case "true":
		return .True
	case "false":
		return .False
	case:
		return .Illegal
	}
}

lexer_next_token :: proc(me: ^Json_Lexer) -> Json_Token {
	lexer_skip_whitespaces(me)
	token := Json_Token {
		location = me.current_location,
		value    = me.text[me.position:me.read_position],
	}
	switch me.current_char {
	case '{':
		token.kind = .LCurly
	case '}':
		token.kind = .RCurly
	case '[':
		token.kind = .LSquare
	case ']':
		token.kind = .RSquare
	case ',':
		token.kind = .Comma
	case 'n', 't', 'f':
		token.value = lexer_read_word(me)
		token.kind = get_token_kind_from_word(token.value)
	case 0:
		token.kind = .EOF
	case:
		token.kind = .Illegal
	}
	lexer_consume(me)
	return token
}
