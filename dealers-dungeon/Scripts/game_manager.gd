extends Node2D

# Smoke test for the Bedrock proxy API.
# game_manager.tscn is the main scene, so just press F5 in Godot and watch
# the Output panel. The call is async: the "Sending" line prints immediately,
# then the ✅ reply or ❌ error prints a moment later.

func _ready() -> void:
	print("[BedrockTest] Sending test prompt to Bedrock proxy...")
	BedrockClient.generate(
		"Reply like your a shop keeper with a massive MAX WIN shop!",
		_on_reply,
		{
			"max_tokens": 64,
			"on_error": _on_error,
		}
	)

func _on_reply(text: String) -> void:
	print("[BedrockTest] ✅ API responded: ", text)

func _on_error(error: String) -> void:
	print("[BedrockTest] ❌ API request failed: ", error)
