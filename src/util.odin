package varg

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"

@(private)
parse_and_set_pointer_by_type :: proc(ptr: rawptr, value: string, ti: ^runtime.Type_Info) -> bool {
	setcast_bool :: proc(ptr: rawptr, $T: typeid, str: string) -> bool {
		ptr := cast(^T)ptr
		ptr^ = cast(T)strconv.parse_bool(str) or_return
		return true
	}

	setcast_i128 :: proc(ptr: rawptr, $T: typeid, str: string) -> bool {
		value := strconv.parse_i128(str) or_return
		if value > cast(i128)max(T) || value < cast(i128)min(T) {
			return false
		}
		ptr := cast(^T)ptr
		ptr^ = cast(T)value
		return true
	}

	setcast_u128 :: proc(ptr: rawptr, $T: typeid, str: string) -> bool {
		value := strconv.parse_u128(str) or_return
		if value > cast(u128)max(T) {
			return false
		}
		ptr := cast(^T)ptr
		ptr^ = cast(T)value
		return true
	}

	setcast_f64 :: proc(ptr: rawptr, $T: typeid, str: string) -> bool {
		ptr := cast(^T)ptr
		ptr^ = cast(T)strconv.parse_f64(str) or_return
		return true
	}

	a := any {ptr, ti.id}

	#partial switch t in ti.variant {
	case runtime.Type_Info_Dynamic_Array:
		ptr := (^runtime.Raw_Dynamic_Array)(ptr)

		// Try to convert the value first.
		elem_backing, mem_err := mem.alloc_bytes(t.elem.size, t.elem.align)
		if mem_err != nil {
			return false
		}
		defer delete(elem_backing)
		parse_and_set_pointer_by_type(raw_data(elem_backing), value, t.elem) or_return

		runtime.__dynamic_array_resize(ptr, t.elem.size, t.elem.align, ptr.len + 1) or_return
		subptr := cast(rawptr)(
			uintptr(ptr.data) +
			uintptr((ptr.len - 1) * t.elem.size))
		mem.copy(subptr, raw_data(elem_backing), len(elem_backing))
	case runtime.Type_Info_Boolean:
		switch b in a {
			case bool: setcast_bool(ptr, bool, value) or_return
			case b8:   setcast_bool(ptr, b8, value) or_return
			case b16:  setcast_bool(ptr, b16, value) or_return
			case b32:  setcast_bool(ptr, b32, value) or_return
			case b64:  setcast_bool(ptr, b64, value) or_return
		}
	case runtime.Type_Info_Rune:
		r := utf8.rune_at_pos(value, 0)
		if r == utf8.RUNE_ERROR { return false }
		ptr := (^rune)(ptr)
		ptr^ = r
	case runtime.Type_Info_String:
		switch s in a {
			case string:
				ptr := (^string)(ptr)
				ptr^ = value
			case cstring:
				ptr := (^cstring)(ptr)
				ptr^ = strings.clone_to_cstring(value)
		}
	case runtime.Type_Info_Integer:
		switch i in a {
			case int:    setcast_i128(ptr, int, value) or_return
			case i8:     setcast_i128(ptr, i8, value) or_return
			case i16:    setcast_i128(ptr, i16, value) or_return
			case i32:    setcast_i128(ptr, i32, value) or_return
			case i64:    setcast_i128(ptr, i64, value) or_return
			case i128:   setcast_i128(ptr, i128, value) or_return
			case i16le:  setcast_i128(ptr, i16le, value) or_return
			case i32le:  setcast_i128(ptr, i32le, value) or_return
			case i64le:  setcast_i128(ptr, i64le, value) or_return
			case i128le: setcast_i128(ptr, i128le, value) or_return
			case i16be:  setcast_i128(ptr, i16be, value) or_return
			case i32be:  setcast_i128(ptr, i32be, value) or_return
			case i64be:  setcast_i128(ptr, i64be, value) or_return
			case i128be: setcast_i128(ptr, i128be, value) or_return

			case uint:   setcast_u128(ptr, uint, value) or_return
			case u8:     setcast_u128(ptr, u8, value) or_return
			case u16:    setcast_u128(ptr, u16, value) or_return
			case u32:    setcast_u128(ptr, u32, value) or_return
			case u64:    setcast_u128(ptr, u64, value) or_return
			case u128:   setcast_u128(ptr, u128, value) or_return
			case u16le:  setcast_u128(ptr, u16le, value) or_return
			case u32le:  setcast_u128(ptr, u32le, value) or_return
			case u64le:  setcast_u128(ptr, u64le, value) or_return
			case u128le: setcast_u128(ptr, u128le, value) or_return
			case u16be:  setcast_u128(ptr, u16be, value) or_return
			case u32be:  setcast_u128(ptr, u32be, value) or_return
			case u64be:  setcast_u128(ptr, u64be, value) or_return
			case u128be: setcast_u128(ptr, u128be, value) or_return
		}
	case runtime.Type_Info_Float:
		switch f in a {
			case f16:   setcast_f64(ptr, f16, value) or_return
			case f32:   setcast_f64(ptr, f32, value) or_return
			case f64:   setcast_f64(ptr, f64, value) or_return
		}
	case:
		return false
	}

	return true
}

@(private)
get_struct_subtag :: proc(tag, id: string) -> (value: string, ok: bool) {
	tag := tag

	for subtag in strings.split_iterator(&tag, ",") {
		if equals := strings.index_byte(subtag, '='); equals != -1 && id == subtag[:equals] {
			return subtag[1 + equals:], true
		} else if id == subtag {
			return "", true
		}
	}

	return "", false
}

@(private)
get_field_name :: proc(field: reflect.Struct_Field) -> string {
	if args_tag, ok := reflect.struct_tag_lookup(field.tag, TAG_ARGS); ok {
		if name_subtag, name_ok := get_struct_subtag(args_tag, SUBTAG_NAME); name_ok {
			return name_subtag
		}
	}

	return field.name
}

// Get a struct field by its field name or "name" subtag.
get_field_by_name :: proc(data: ^$T, name: string) -> (field: reflect.Struct_Field, err: Error) {
	for field in reflect.struct_fields_zipped(T) {
		if get_field_name(field) == name {
			return field, nil
		}
	}

	return {}, Parse_Error {
		.Missing_Field,
		fmt.tprintf("unable to find argument by name `%s`", name)
	}
}

// Get a struct field by its "pos" subtag.
get_field_by_pos :: proc(data: ^$T, index: int) -> (field: reflect.Struct_Field, ok: bool) {
	fields := reflect.struct_fields_zipped(T)

	for field in fields {
		args_tag, tag_ok := reflect.struct_tag_lookup(field.tag, TAG_ARGS)
		if !tag_ok {
			continue
		}

		pos_subtag, pos_ok := get_struct_subtag(args_tag, SUBTAG_POS)
		if !pos_ok {
			continue
		}

		value, parse_ok := strconv.parse_int(pos_subtag)
		if parse_ok && value == index {
			return field, true
		}
	}

	return {}, false
}
