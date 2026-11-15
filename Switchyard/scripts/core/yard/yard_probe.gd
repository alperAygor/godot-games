class_name YardProbe
extends RefCounted
## O yönde adım mümkün mü, baş dal seçimi istiyor mu (görünüm sürüklerken sorar).

var possible: bool = false
var needs_branch: bool = false
## needs_branch ise iki dalın ilk hücreleri (sıra = dal numarası 0, 1).
var branch_cells: PackedInt32Array = PackedInt32Array()
