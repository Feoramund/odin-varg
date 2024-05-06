package tests

import "core:math"
import "core:testing"
import "core:unicode/utf8"

import varg "../src"

IO :: struct {
	i: string,
	o: string,
}

@(test)
test_no_args :: proc(t: ^testing.T) {
	s: IO
	args: []string
	result := varg.parse(&s, args)
	testing.expect_value(t, result, nil)
}

@(test)
test_two_flags :: proc(t: ^testing.T) {
	s: IO
	args := [?]string { "-i:hellope", "-o:world" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.i, "hellope")
	testing.expect_value(t, s.o, "world")
}

@(test)
test_extra_arg :: proc(t: ^testing.T) {
	s: IO
	args := [?]string { "-i:hellope", "-o:world", "extra" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Extra_Pos)
	}
}

@(test)
test_string_into_int :: proc(t: ^testing.T) {
	S :: struct {
		n: int,
	}
	s: S
	args := [?]string { "-n:hellope" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Bad_Type)
	}
}

@(test)
test_string_into_bool :: proc(t: ^testing.T) {
	S :: struct {
		b: bool,
	}
	s: S
	args := [?]string { "-b:hellope" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Bad_Type)
	}
}

@(test)
test_bools :: proc(t: ^testing.T) {
	S :: struct {
		a, b, c, d: bool,
	}
	s: S
	args := [?]string { "-a:false", "-b:true", "-c:1", "-d" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, false)
	testing.expect_value(t, s.b, true)
	testing.expect_value(t, s.c, true)
	testing.expect_value(t, s.d, true)
}

@(test)
test_ints :: proc(t: ^testing.T) {
	S :: struct {
		a, u8,
		b: i8,
		c: uint,
		d: int,
		e: u16,
		f: i16,
	}
	s: S
	args := [?]string { "-a:100", "-b:-32", "-c:80000", "-d:-9000", "-e:64000", "-f:32000" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 100)
	testing.expect_value(t, s.b, -32)
	testing.expect_value(t, s.c, 80000)
	testing.expect_value(t, s.d, -9000)
	testing.expect_value(t, s.e, 64000)
	testing.expect_value(t, s.f, 32000)
}

@(test)
test_floats :: proc(t: ^testing.T) {
	S :: struct {
		a: f16,
		b: f32,
		c: f64,
		d: f64,
		e: f64,
	}
	s: S
	args := [?]string { "-a:100", "-b:3.14", "-c:-123.456", "-d:nan", "-e:inf" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 100)
	testing.expect_value(t, s.b, 3.14)
	testing.expect_value(t, s.c, -123.456)
	testing.expect(t, math.is_nan(s.d))
	testing.expect(t, math.is_inf(s.e))
}

@(test)
test_strings :: proc(t: ^testing.T) {
	S :: struct {
		a, b, c: string,
		d: cstring,
	}
	s: S
	args := [?]string { "-a:", "-b:hellope", "-c:spaced out", "-d:cstr" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, "")
	testing.expect_value(t, s.b, "hellope")
	testing.expect_value(t, s.c, "spaced out")
	testing.expect_value(t, s.d, "cstr")
}

@(test)
test_runes :: proc(t: ^testing.T) {
	S :: struct {
		a, b, c: rune,
	}
	s: S
	args := [?]string { "-a:a", "-b:ツ", "-c:99" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 'a')
	testing.expect_value(t, s.b, 'ツ')
	testing.expect_value(t, s.c, '9')
}

@(test)
test_bad_rune :: proc(t: ^testing.T) {
	S :: struct {
		a: rune,
	}
	s: S
	args := [?]string { "-a:" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Bad_Type)
	}
}

@(test)
test_overflow :: proc(t: ^testing.T) {
	S :: struct {
		a: u8,
	}
	s: S
	args := [?]string { "-a:256" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Bad_Type)
	}
}

@(test)
test_underflow :: proc(t: ^testing.T) {
	S :: struct {
		a: i8,
	}
	s: S
	args := [?]string { "-a:-129" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Bad_Type)
	}
}

@(test)
test_arrays :: proc(t: ^testing.T) {
	S :: struct {
		a: [dynamic]string,
		b: [dynamic]int,
	}
	s: S
	args := [?]string { "-a:abc", "-b:1", "-a:foo", "-b:3" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.a), 2)
	testing.expect_value(t, len(s.b), 2)

	if len(s.a) < 2 || len(s.b) < 2 {
		return
	}

	testing.expect_value(t, s.a[0], "abc")
	testing.expect_value(t, s.a[1], "foo")
	testing.expect_value(t, s.b[0], 1)
	testing.expect_value(t, s.b[1], 3)
}

@(test)
test_varargs :: proc(t: ^testing.T) {
	S :: struct {
		pos: [dynamic]string,
	}
	s: S
	args := [?]string { "abc", "foo", "bar" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.pos), 3)

	if len(s.pos) < 3 {
		return
	}

	testing.expect_value(t, s.pos[0], "abc")
	testing.expect_value(t, s.pos[1], "foo")
	testing.expect_value(t, s.pos[2], "bar")
}

@(test)
test_mixed_varargs :: proc(t: ^testing.T) {
	S :: struct {
		input: string `args:"pos=0"`,
		pos: [dynamic]string,
	}
	s: S
	args := [?]string { "abc", "foo", "bar" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.pos), 2)

	if len(s.pos) < 2 {
		return
	}

	testing.expect_value(t, s.input, "abc")
	testing.expect_value(t, s.pos[0], "foo")
	testing.expect_value(t, s.pos[1], "bar")
}

@(test)
test_maps :: proc(t: ^testing.T) {
	S :: struct {
		a: map[string]string,
		b: map[string]int,
	}
	s: S
	args := [?]string { "-a:abc=foo", "-b:bar=42" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.a), 1)
	testing.expect_value(t, len(s.b), 1)

	if len(s.a) < 1 || len(s.b) < 1 {
		return
	}

	abc, has_abc := s.a["abc"]
	bar, has_bar := s.b["bar"]

	testing.expect_value(t, abc, "foo")
	testing.expect_value(t, bar, 42)
}

@(test)
test_invalid_map_syntax :: proc(t: ^testing.T) {
	S :: struct {
		a: map[string]string,
	}
	s: S
	args := [?]string { "-a:foo:42" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Missing_Value)
	}
}

@(test)
test_tags_pos :: proc(t: ^testing.T) {
	S :: struct {
		b: int `args:"pos=1"`,
		a: int `args:"pos=0"`,
	}
	s: S
	args := [?]string { "42", "99" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 42)
	testing.expect_value(t, s.b, 99)
}

@(test)
test_tags_name :: proc(t: ^testing.T) {
	S :: struct {
		a: int `args:"name=alice"`,
		b: int `args:"name=bill"`,
	}
	s: S
	args := [?]string { "-alice:1", "-bill:2" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 1)
	testing.expect_value(t, s.b, 2)
}

@(test)
test_tags_required :: proc(t: ^testing.T) {
	S :: struct {
		a: int,
		b: int `args:"required"`,
	}
	s: S
	args := [?]string { "-a:1" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Validation_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
}

@(test)
test_tags_required_pos :: proc(t: ^testing.T) {
	S :: struct {
		a: int `args:"pos=0,required"`,
		b: int `args:"pos=1"`,
	}
	s: S
	args := [?]string { "-b:5" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Validation_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
}

@(test)
test_tags_pos_out_of_order :: proc(t: ^testing.T) {
	S :: struct {
		a: int `args:"pos=2"`,
		pos: [dynamic]int,
	}
	s: S
	args := [?]string { "1", "2", "3", "4" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.pos), 3)

	if len(s.pos) < 3 {
		return
	}

	testing.expect_value(t, s.a, 3)
	testing.expect_value(t, s.pos[0], 1)
	testing.expect_value(t, s.pos[1], 2)
	testing.expect_value(t, s.pos[2], 4)
}

@(test)
test_missing_field :: proc(t: ^testing.T) {
	S :: struct {
		a: int,
	}
	s: S
	args := [?]string { "-b" }
	result := varg.parse(&s, args[:])
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Missing_Field)
	}
}

@(test)
test_alt_syntax :: proc(t: ^testing.T) {
	S :: struct {
		a: int,
	}
	s: S
	args := [?]string { "-a=3" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, result, nil)
	testing.expect_value(t, s.a, 3)
}

@(test)
test_strict_returns_first_error :: proc(t: ^testing.T) {
	S :: struct {
		b: int,
		c: int,
	}
	s: S
	args := [?]string { "-a=3", "-b=3" }
	result := varg.parse(&s, args[:], strict=true)
	err, ok := result.(varg.Parse_Error)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Missing_Field)
	}
}

@(test)
test_non_strict_returns_last_error :: proc(t: ^testing.T) {
	S :: struct {
		a: int,
		b: int,
	}
	s: S
	args := [?]string { "-a=foo", "-b=2", "-c=3" }
	result := varg.parse(&s, args[:], strict=false)
	err, ok := result.(varg.Parse_Error)
	testing.expect_value(t, s.b, 2)
	testing.expectf(t, ok, "unexpected result: %v", result)
	if ok {
		testing.expect_value(t, err.type, varg.Parse_Error_Type.Missing_Field)
	}
}

@(test)
test_map_overwrite :: proc(t: ^testing.T) {
	S :: struct {
		m: map[string]int
	}
	s: S
	args := [?]string { "-m:foo=3", "-m:foo=5" }
	result := varg.parse(&s, args[:], strict=false)
	testing.expect_value(t, result, nil)
	testing.expect_value(t, len(s.m), 1)
	foo, has_foo := s.m["foo"]
	testing.expect(t, has_foo)
	testing.expect_value(t, foo, 5)
}

@(test)
test_maps_of_arrays :: proc(t: ^testing.T) {
	// Why you would ever want to do this, I don't know, but it's possible!
	S :: struct {
		m: map[string][dynamic]int,
	}
	s: S
	args := [?]string { "-m:foo=1", "-m:foo=2", "-m:bar=3" }
	result := varg.parse(&s, args[:])
	testing.expect_value(t, len(s.m), 2)

	if len(s.m) != 2 {
		return
	}

	foo, has_foo := s.m["foo"]
	bar, has_bar := s.m["bar"]

	testing.expect_value(t, has_foo, true)
	testing.expect_value(t, has_bar, true)

	if has_foo {
		testing.expect_value(t, len(foo), 2)
		if len(foo) == 2 {
			testing.expect_value(t, foo[0], 1)
			testing.expect_value(t, foo[1], 2)
		}
	}

	if has_bar {
		testing.expect_value(t, len(bar), 1)
		if len(bar) == 1 {
			testing.expect_value(t, bar[0], 3)
		}
	}
}
