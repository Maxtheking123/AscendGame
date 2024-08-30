extends RichTextLabel

var label = Label.new()
label.bbcode_enabled = true

# Set the custom font if it's not already set in the font file
var custom_font = DynamicFont.new()
custom_font.font_data = load("res://path_to_your_font_file.tres")
custom_font.size = 14
label.add_font_override("font", custom_font)

add_child(label)
