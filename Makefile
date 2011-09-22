FILENAME=bookmarks
NODE_BIN=~/node_modules/.bin

compiled/%.js: %.coffee compiled
	coffee --compile --bare --print $< | uglifyjs >$@

compiled/%.css: %.less compiled
	$(NODE_BIN)/lessc -x $< $@

docs/%.html: %.coffee
	$(NODE_BIN)/docco $<

default: compiled/$(FILENAME).js compiled/$(FILENAME).css

compiled:
	mkdir -p compiled

docs: docs/$(FILENAME).html

clean:
	rm -rf compiled docs

watch: compiled
	coffee --compile --bare --watch --output compiled $(FILENAME).coffee
