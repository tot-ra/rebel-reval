class_name ForgedRecord
extends RefCounted

var record_id: StringName:
	get:
		return _record_id
var commission_id: StringName:
	get:
		return _commission_id
var item_id: StringName:
	get:
		return _item_id
var modification_id: StringName:
	get:
		return _modification_id

var _record_id: StringName
var _commission_id: StringName
var _item_id: StringName
var _modification_id: StringName


func _init(
	p_record_id: StringName,
	p_commission_id: StringName,
	p_item_id: StringName,
	p_modification_id: StringName
) -> void:
	_record_id = p_record_id
	_commission_id = p_commission_id
	_item_id = p_item_id
	_modification_id = p_modification_id
