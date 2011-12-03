COFFEE=$(wildcard scripts/*.coffee)
LESS=styles/bookmarks.less
NODE_BIN=$(shell npm bin)

JS=$(addprefix compiled/,$(notdir $(COFFEE:coffee=js)))
CSS=$(addprefix compiled/,$(notdir $(LESS:less=css)))
DOCS=$(addprefix docs/,$(notdir $(COFFEE:coffee=html)))

compiled/%.js: scripts/%.coffee compiled
	coffee --compile --bare --print $< | uglifyjs >$@

compiled/%.css: styles/%.less compiled
	$(NODE_BIN)/lessc -x $< $@

default: $(JS) $(CSS)

compiled:
	mkdir -p compiled

.PHONY: docs
docs:
	$(NODE_BIN)/docco $(COFFEE)

clean:
	rm -rf compiled docs

watch: compiled
	coffee --compile --bare --watch --output compiled $(COFFEE)
