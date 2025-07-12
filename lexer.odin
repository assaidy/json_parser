package main

import "core:fmt"
import "core:unicode"

Token_Kind :: enum {
	EOF,
	ILLEGAL_LITERAL,
	ILLEGAL_UNTERMINATED_STRING,
	ILLEGAL_NUMBER,
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
	NUMBER,
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
	for unicode.is_white_space(rune(me.current_char)) {
		lexer_consume(me)
	}
}

lexer_read_word :: proc(me: ^Json_Lexer) -> string {
	position := me.position
	for unicode.is_alpha(rune(lexer_peek(me))) {
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
		return .ILLEGAL_LITERAL
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
		previous := me.current_char
		lexer_consume(me)
		if me.current_char == '\\' && lexer_peek(me) == '"' && previous != '\\' do lexer_consume(me)
	}
	defer lexer_consume(me)
	return me.text[position:me.read_position], .STRING

}

lexer_read_number :: proc(me: ^Json_Lexer) -> (string, Token_Kind) {
	start_position := me.position
	got_minus: bool
	got_point: bool
	// ensure minus only appears on the left
	is_negative := me.current_char == '-'
	if is_negative {
		if next := lexer_peek(me); !('0' <= next && next <= '9' || next == '.') {
			return "", .ILLEGAL_NUMBER
		}
	}

	in_exponent_part: bool
	accept_plus_in_exponent: bool
	accept_minus_in_exponent: bool

	loop: for me.current_char != 0 {
		switch me.current_char {
		case '-':
			if in_exponent_part {
				if !accept_minus_in_exponent do break loop
				accept_minus_in_exponent = false
			} else {
				if got_minus || !is_negative do break loop
				got_minus = true
			}
		case '+':
			if !in_exponent_part || !accept_plus_in_exponent do break loop
			accept_plus_in_exponent = false
		case '.':
			// ensure no points in the exponent part
			if in_exponent_part do break loop

			if got_point do break loop
			got_point = true
			// ensure there is at least one digit after the point
			if next := lexer_peek(me); !('0' <= next && next <= '9') {
				return "", .ILLEGAL_NUMBER
			}
		case 'E', 'e':
			if in_exponent_part do break loop
			in_exponent_part = true
			if next := lexer_peek(me);
			   !(next == '+' || next == '-' || '0' <= next && next <= '9') {
				return "", .ILLEGAL_NUMBER
			}
			if next := lexer_peek(me); next == '-' {
				accept_minus_in_exponent = true
			} else if next == '+' {
				accept_plus_in_exponent = true
			}
		case '0' ..= '9':
		// don't do anything. we consume at the end of the iteration
		// odin will not step to the next case block
		case:
			break loop
		}
		lexer_consume(me)
	}

	end_position := me.read_position if me.current_char == 0 else me.position
	return me.text[start_position:end_position], .NUMBER
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
	case '0' ..= '9', '-', '.':
		token.value, token.kind = lexer_read_number(me)
		return token // avoid consuming
	case 0:
		token.kind = .EOF
		token.value = ""
	case:
		token.kind = .ILLEGAL_LITERAL
	}
	lexer_consume(me)
	return token
}
