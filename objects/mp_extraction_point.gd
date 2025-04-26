extends Area3D

var value := 0

@export
var target := 15000

func _ready() -> void:
	$CostLabel.text = "Собрано: %s/%s" % [str(value), str(target)]

func _on_body_entered(body: Node3D) -> void:
	if body is MPProp:
		value += body.value
		$CostLabel.text = "Собрано: %s/%s" % [str(value), str(target)]
		
		if value >= target:
			$Control.show()
func _on_body_exited(body: Node3D) -> void:
	if body is MPProp:
		value -= body.value
		$CostLabel.text = "Собрано: %s/%s" % [str(value), str(target)]
