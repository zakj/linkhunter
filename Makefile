CHROME_DIR=Chrome/b
CHROME_LOCALE=Chrome/_locales/en
SAFARI_DIR=Linkhunter.safariextension/b

# TODO: Investigate RequireJS+r.js or the like. The CS/JS build/concat process
# with dependencies is getting kind of ridiculous.

.PHONY: default common safari chrome
default: chrome safari

common: build/vendor.js build/templates.js build/common.js build/linkhunter.css linkhunter.html

chrome: common
	mkdir -p $(CHROME_DIR) $(CHROME_LOCALE)
	./messages.py --chrome >$(CHROME_LOCALE)/messages.json
	cp build/{vendor.js,templates.js,linkhunter.css} $(CHROME_DIR)
	coffee --compile -o $(CHROME_DIR) scripts/chrome/*.coffee
	uglifyjs <build/common.js >$(CHROME_DIR)/linkhunter.js
	cp linkhunter.html $(CHROME_DIR)

safari: common
	mkdir -p $(SAFARI_DIR)
	cp build/{vendor.js,templates.js,linkhunter.css} $(SAFARI_DIR)
	coffee --compile -o $(SAFARI_DIR) scripts/safari/*.coffee
	./messages.py --safari >$(SAFARI_DIR)/linkhunter.js
	uglifyjs <build/common.js >>$(SAFARI_DIR)/linkhunter.js
	cp linkhunter.html $(SAFARI_DIR)

build:
	mkdir -p build

# Order is important; some of these depend on others.
build/vendor.js: build vendor/*.js
	cat vendor/{jquery-1.7.min.js,underscore-min.js,backbone-min.js,handlebars.runtime-v3.0.0.js,moment.min.js} \
		| uglifyjs >$@

build/templates.js: build templates/*
	handlebars templates | uglifyjs >$@

build/common.js: build scripts/*.coffee
	coffee --compile --join $@ \
		scripts/{support,bookmarks,browser,config,linkhunter}.coffee

build/linkhunter.css: build styles/*.styl
	stylus --compress --inline --use nib -o build styles/linkhunter.styl

.PHONY: docs
docs:
	docco scripts/*.coffee

.PHONY: clean
clean:
	rm -rf build docs $(CHROME_DIR) $(CHROME_LOCALE) $(SAFARI_DIR)

pack-chrome: chrome
	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
		--pack-extension=$(shell pwd)/Chrome \
		--pack-extension-key=$$HOME/Dropbox/Projects/Linkhunter/linkhunter.pem

# release: default
# 	mkdir release
# 	git archive master | tar -C release -xf -
# 	cd release && make && zip -r ../linkhunter-$$(awk -F '"' '/"version":/ { print $$4 }' manifest.json).zip *
# 	rm -rf release
