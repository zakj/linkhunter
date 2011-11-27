COFFEE=background.coffee bookmarks.coffee config.coffee content.coffee linkhunter.coffee
LESS=bookmarks.less
NODE_BIN=~/node_modules/.bin

JS=$(addprefix compiled/,$(COFFEE:.coffee=.js))
CSS=$(addprefix compiled/,$(LESS:.less=.css))

compiled/%.js: %.coffee compiled
	coffee --compile --bare --print $< | uglifyjs >$@

compiled/%.css: %.less compiled
	$(NODE_BIN)/lessc -x $< $@

docs/%.html: %.coffee
	$(NODE_BIN)/docco $<

default: $(JS) $(CSS)

compiled:
	mkdir -p compiled

docs: docs/$(FILENAME).html

clean:
	rm -rf compiled docs

watch: compiled
	coffee --compile --bare --watch --output compiled $(COFFEE)
