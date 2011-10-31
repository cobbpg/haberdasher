all:
	mxmlc -static-link-runtime-shared-libraries=true -compiler.include-libraries Clipper.swc -optimize=true -actionscript-file-encoding=UTF-8 haberdasher.as

clean:
	rm -f *.swf
