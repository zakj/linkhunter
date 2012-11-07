CHROME_DIR=Chrome/b
SAFARI_DIR=Linkhunter.safariextension/b

# TODO: Investigate RequireJS+r.js or the like. The CS/JS build/concat process
# with dependencies is getting kind of ridiculous.

.PHONY: default common safari chrome
default: chrome safari

common: build/vendor.js build/templates.js build/common.js build/linkhunter.css linkhunter.html

chrome: common
	mkdir -p $(CHROME_DIR)
	cp build/{vendor.js,templates.js,linkhunter.css} $(CHROME_DIR)
	coffee --compile --print scripts/chrome/*.coffee >build/chrome.js
	cat build/{common,chrome}.js | uglifyjs >$(CHROME_DIR)/linkhunter.js
	cp linkhunter.html $(CHROME_DIR)

safari: common
	mkdir -p $(SAFARI_DIR)
	cp build/{vendor.js,templates.js,linkhunter.css} $(SAFARI_DIR)
	uglifyjs <build/common.js >$(SAFARI_DIR)/linkhunter.js
	cp linkhunter.html $(SAFARI_DIR)

build:
	mkdir -p build

# Order is important; some of these depend on others.
build/vendor.js: build vendor/*.js
	cat vendor/{jquery-1.7,underscore,backbone,handlebars.runtime,moment}[.-]min.js \
		| uglifyjs >$@

build/templates.js: build templates/*
	handlebars templates | uglifyjs >$@

build/common.js: build scripts/*.coffee
	coffee --compile --join $@ \
		scripts/{bookmarks,browser,config,linkhunter}.coffee

build/linkhunter.css: build styles/*.styl
	stylus --compress --inline --use nib -o build styles/linkhunter.styl

.PHONY: docs
docs:
	docco scripts/*.coffee

.PHONY: clean
clean:
	rm -rf build docs


# pack: default
# 	'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
# 		--pack-extension=$(shell pwd) \
# 		--pack-extension-key=$$HOME/Dropbox/Projects/Linkhunter/linkhunter.pem

# release: default
# 	mkdir release
# 	git archive master | tar -C release -xf -
# 	cd release && make && zip -r ../linkhunter-$$(awk -F '"' '/"version":/ { print $$4 }' manifest.json).zip *
# 	rm -rf release
