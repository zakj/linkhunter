COFFEE=$(wildcard scripts/*.coffee)
STYLUS=styles/linkhunter.styl
NODE_BIN=$(shell npm bin)

JS=$(addprefix compiled/,$(notdir $(COFFEE:coffee=js))) compiled/templates.js
CSS=$(addprefix compiled/,$(notdir $(STYLUS:styl=css)))
DOCS=$(addprefix docs/,$(notdir $(COFFEE:coffee=html)))

compiled/%.js: scripts/%.coffee compiled
	$(NODE_BIN)/coffee --compile --bare --print $< | uglifyjs >$@

compiled/%.css: styles/%.styl compiled
	$(NODE_BIN)/stylus --use nib -o compiled $<

default: $(JS) $(CSS)

compiled/templates.js: compiled templates/*
	$(NODE_BIN)/handlebars -f $@ templates

pack: default
	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
		--pack-extension=$(shell pwd) \
		--pack-extension-key=$$HOME/Dropbox/Projects/Linkhunter/linkhunter.pem
	
compiled:
	mkdir -p compiled

.PHONY: docs
docs:
	$(NODE_BIN)/docco $(COFFEE)

clean:
	rm -rf compiled docs

watch: compiled
	$(NODE_BIN)/coffee --compile --bare --watch --output compiled $(COFFEE)

release: default
	mkdir release
	git archive master | tar -C release -xf -
	cd release && make && zip -r ../linkhunter-$$(awk -F '"' '/"version":/ { print $$4 }' manifest.json).zip *
	rm -rf release
