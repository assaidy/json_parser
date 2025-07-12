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

check_test_case :: proc(t: ^testing.T, i: int, tt: Test_Case, value: Json_Value, err: Error) {
	testing.expectf(
		t,
		tt.expected_error == err,
		"expected error: %v, got: %v",
		tt.expected_error,
		err,
	)
	testing.expectf(
		t,
		compare_values(tt.ouptut, value),
		"expected value: %v, got: %v",
		tt.ouptut,
		value,
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

@(test) // TODO:
test_number :: proc(t: ^testing.T) {
	tests := []Test_Case{}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test) // TODO:
test_object :: proc(t: ^testing.T) {
	tests := []Test_Case{}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}

@(test) // TODO:
test_array :: proc(t: ^testing.T) {
	tests := []Test_Case{}

	for tt, i in tests {
		value, err := parse_json_text(tt.input)
		check_test_case(t, i, tt, value, err)
		json_value_destroy(value)
	}
}
