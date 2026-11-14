class_name Calculator
extends RefCounted
## Masadaki hesap makinesi (yardımcı araç; oyun hesabı değil). Anında işlem yapan basit dört işlem makinesi.
## Tuşlar: "0".."9", ".", "+", "-", "*", "/" (ya da "−", "×", "÷"), "=", "C", "<" (geri sil).

const MAX_DIGITS := 12
const ERROR_TEXT := "Hata"

var display := "0"

var _left := 0.0
var _op := ""
var _input := ""
var _just_evaluated := false
var _error := false


func press(key: String) -> void:
	if _error:
		_reset()
	match key:
		"C":
			_reset()
		"<":
			_backspace()
		".":
			_digit(".")
		"+", "-", "−", "*", "×", "/", "÷":
			_operator(_normalize(key))
		"=":
			_equals()
		_:
			if key.length() == 1 and key.is_valid_int():
				_digit(key)


## Ekrandaki sayı.
func value() -> float:
	return display.to_float() if not _error else 0.0


func _normalize(key: String) -> String:
	return {"−": "-", "×": "*", "÷": "/"}.get(key, key)


func _reset() -> void:
	display = "0"
	_left = 0.0
	_op = ""
	_input = ""
	_just_evaluated = false
	_error = false


func _digit(key: String) -> void:
	if _just_evaluated:
		_left = 0.0
		_just_evaluated = false
	if _input.length() >= MAX_DIGITS:
		return
	if key == ".":
		if "." in _input:
			return
		_input = "0." if _input.is_empty() else _input + "."
	elif _input == "0":
		_input = key
	else:
		_input += key
	display = _input


func _backspace() -> void:
	if _input.is_empty():
		return
	_input = _input.left(_input.length() - 1)
	display = _input if not _input.is_empty() else "0"


func _operator(op: String) -> void:
	if not _input.is_empty():
		if _op.is_empty():
			_left = _input.to_float()
		else:
			if not _apply():
				return
		_input = ""
	elif _just_evaluated or _op.is_empty():
		_left = display.to_float()
	_op = op
	_just_evaluated = false
	display = _format(_left)


func _equals() -> void:
	if _op.is_empty() or _input.is_empty():
		return
	if _apply():
		_op = ""
		_input = ""
		_just_evaluated = true
		display = _format(_left)


## Bekleyen işlemi uygular; sıfıra bölmede hata verir ve false döner.
func _apply() -> bool:
	var right := _input.to_float()
	match _op:
		"+":
			_left += right
		"-":
			_left -= right
		"*":
			_left *= right
		"/":
			if is_zero_approx(right):
				_error = true
				display = ERROR_TEXT
				return false
			_left /= right
	return true


func _format(number: float) -> String:
	if is_equal_approx(number, roundf(number)) and absf(number) < 1e12:
		return str(int(roundf(number)))
	var text := "%.6f" % number
	while text.ends_with("0"):
		text = text.left(text.length() - 1)
	return text
