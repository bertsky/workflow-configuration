INPUT := $(or $(OUTPUT),$(INPUT),OCR-D-IMG)

OUTPUT: $(INPUT)
OUTPUT:
	@shopt -s nullglob; cat $</*.txt $</*.xml

OUTPUT := OUTPUT
