#+feature dynamic-literals
package main

import "core:fmt"
import "core:testing"

compare_values :: proc(value1, value2: Json_Value) -> bool {
	switch v1 in value1 {
	case Null:
		_ = value2.(Null) or_return
	case Boolean:
		v2 := value2.(Boolean) or_return
		return v1 == v2
	case Number:
		v2 := value2.(Number) or_return
		return v1 == v2
	case String:
		v2 := value2.(string) or_return
		return v1 == v2
	case Object:
		v2 := value2.(Object) or_return
		return compare_objects(v1, v2)
	case Array:
		v2 := value2.(Array) or_return
		return compare_arrays(v1, v2)
	}
	return true
}

compare_objects :: proc(object1, object2: Object) -> bool {
	if len(object1) != len(object2) do return false
	for k, v1 in object1 {
		v2 := object2[k] or_return
		if !compare_values(v1, v2) do return false
	}
	return true
}

compare_arrays :: proc(array1, array2: Array) -> bool {
	if len(array1) != len(array2) do return false
	for i in 0 ..< len(array1) {
		if !compare_values(array1[i], array2[i]) do return false
	}
	return true
}

Test_Case :: struct {
	input:          string,
	ouptut:         Json_Value,
	expected_error: Error,
}

check_test_case :: proc(
	t: ^testing.T,
	i: int,
	tt: Test_Case,
	value: Json_Value,
	err: Error,
	loc := #caller_location,
) {
	testing.expectf(
		t,
		tt.expected_error == err,
		"[%d] expected error: %v, got: %v",
		i,
		tt.expected_error,
		err,
		loc = loc,
	)
	testing.expectf(
		t,
		compare_values(tt.ouptut, value),
		"[%d] expected value: %v, got: %v",
		i,
		tt.ouptut,
		value,
		loc = loc,
	)
}

@(test)
test_keywords :: proc(t: ^testing.T) {
	tests := []Test_Case {
		{`null`, Null{}, .None},
		{`true`, Boolean(true), .None},
		{`false`, Boolean(false), .None},
		{`something`, nil, .Invalid_Json_Literal},
		{`nullx`, nil, .Invalid_Json_Literal},
		{``, nil, .Empty_Text},
	}

	for tt, i in tests {
		value, err := parse_json_text(tt.input, context.temp_allocator)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test)
test_string :: proc(t: ^testing.T) {
	tests := []Test_Case {
		{`""`, String(""), .None},
		{`"ODIN"`, String("ODIN"), .None},
		{`"\""`, String("\""), .None},
		{`"\\"`, String("\\"), .None},
		{`"\/"`, String("/"), .None},
		{`"\b"`, String("\b"), .None},
		{`"\f"`, String("\f"), .None},
		{`"\n"`, String("\n"), .None},
		{`"\r"`, String("\r"), .None},
		{`"\t"`, String("\t"), .None},
		{`"\u"`, nil, .Invalid_Escape_Sequence},
		{`"\ua"`, nil, .Invalid_Escape_Sequence},
		{`"\uaa"`, nil, .Invalid_Escape_Sequence},
		{`"\uaaa"`, nil, .Invalid_Escape_Sequence},
		{`"\uaaaa"`, String("\uaaaa"), .None},
		{`"ABC\uaaaaABC"`, String("ABC\uaaaaABC"), .None},
		{`"\"`, nil, .Unterminated_String},
	}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test)
test_number :: proc(t: ^testing.T) {
	tests := []Test_Case {
		{`0`, Number(0.0), .None},
		{`-0`, Number(-0.0), .None},
		{`123`, Number(123.0), .None},
		{`-123`, Number(-123.0), .None},
		{`3.14`, Number(3.14), .None},
		{`-3.14`, Number(-3.14), .None},
		{`1e10`, Number(1e10), .None},
		{`-1E-10`, Number(-1e-10), .None},
		{`1.0e+5`, Number(1.0e+5), .None},
		{`0123`, Number(123), .None},
		{`1.`, nil, .Invalid_Number},
		{`.5`, Number(0.5), .None},
		{`--1`, nil, .Invalid_Number},
	}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test)
test_object :: proc(t: ^testing.T) {
	tests := []Test_Case {
		{`{}`, Object{}, .None},
		{`{"a":1}`, Object{"a" = Number(1.0)}, .None},
		{`{"a":true, "b":null}`, Object{"a" = Boolean(true), "b" = Null{}}, .None},
		{`{"nested":{"x":10}}`, Object{"nested" = Object{"x" = Number(10.0)}}, .None},
		{
			`{ "a" : { "b" : { "c" : null } } }`,
			Object{"a" = Object{"b" = Object{"c" = Null{}}}},
			.None,
		},
		{`{"name": "Ahmad Assaidy"}`, Object{"name" = String("Ahmad Assaidy")}, .None},

		// Invalid cases
		{`{`, nil, .Unterminated_Object},
		{`{"a"}`, nil, .Missing_Colon_After_Key},
		{`{"a":}`, nil, .Unexpected_Token},
		{`{"a":1,}`, nil, .Trailing_Comma_Not_Allowed},
		{`{123: "value"}`, nil, .Missing_Object_Key},
		{`{"a":1 "b":2}`, nil, .Missing_Comma_Between_Elements},
		{`{"a":1,"a":2}`, nil, .Duplicate_Object_Key},
	}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test)
test_array :: proc(t: ^testing.T) {
	tests := []Test_Case {
		{`[]`, Array{}, .None},
		{`[null]`, Array{Null{}}, .None},
		{`[true, false]`, Array{Boolean(true), Boolean(false)}, .None},
		{`[1, 2, 3]`, Array{Number(1.0), Number(2.0), Number(3.0)}, .None},
		{`["a", "b", "c"]`, Array{String("a"), String("b"), String("c")}, .None},
		{`[{"a":1}, {"b":2}]`, Array{Object{"a" = Number(1.0)}, Object{"b" = Number(2.0)}}, .None},
		{
			`[[1, 2], [3, 4]]`,
			Array{Array{Number(1.0), Number(2.0)}, Array{Number(3.0), Number(4.0)}},
			.None,
		},
		{
			`[1, "two", null, true, {"key": "value"}, [5]]`,
			Array {
				Number(1.0),
				String("two"),
				Null{},
				Boolean(true),
				Object{"key" = String("value")},
				Array{Number(5.0)},
			},
			.None,
		},

		// Invalid arrays
		{`[`, nil, .Unterminated_Array},
		{`[1,]`, nil, .Trailing_Comma_Not_Allowed},
		{`[,1]`, nil, .Unexpected_Token},
		{`[1 2]`, nil, .Missing_Comma_Between_Elements},
		{`[1,,2]`, nil, .Unexpected_Token},
		{`[1, true false]`, nil, .Missing_Comma_Between_Elements},
		{`[`, nil, .Unterminated_Array},
		{``, nil, .Empty_Text},
	}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}
