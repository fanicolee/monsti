GOPATH=$(PWD)/go/
GO=GOPATH=$(GOPATH) go
#GO_COMMON_OPTS=-race
GO_GET=$(GO) get $(GO_COMMON_OPTS)
GO_BUILD=$(GO) build $(GO_COMMON_OPTS)
GO_TEST=$(GO) test $(GO_COMMON_OPTS)

MODULES=daemon httpd data document contactform mail image

VCS_REVISION=`git rev-list HEAD --count`
VCS_BRANCH=`git branch | sed -n '/\* /s///p'`
MONSTI_VERSION=0.7.0.dev.$(VCS_BRANCH).$(VCS_REVISION)
DEB_VERSION=1

DIST_PATH=dist/monsti-$(MONSTI_VERSION)

ALOHA_VERSION=0.23.2

MODULE_PROGRAMS=$(MODULES:%=go/bin/monsti-%)

all: monsti bcrypt

monsti: modules templates locales templates/master.html dep-aloha-editor dep-jquery

.PHONY: bcrypt
bcrypt: 
	mkdir -p $(GOPATH)/bin
	cd utils/bcrypt && $(GO_GET) -d . && $(GO_BUILD) -o $(GOPATH)/bin/bcrypt .

modules: $(MODULES)
$(MODULES): %: go/bin/monsti-%

locales: $(MODULES:%=locales-monsti-%)

locales-monsti-%:
	mkdir -p locale/
	mkdir -p core/$*/locale/
	cp -Rn core/$*/locale .

templates: $(MODULES:%=templates-monsti-%)

templates-monsti-%:
	mkdir -p templates/
	mkdir -p core/$*/templates/
	ln -nsf ../core/$*/templates templates/$*

templates/master.html: templates/httpd/master.html
	for i in $(wildcard templates/httpd/*); \
	do \
		ln -nsf httpd/`basename $${i}` templates/`basename $${i}`; \
	done; \
  #rm templates/httpd/templates

core/%:
	git clone git@gitorious.org:monsti/$*.git core/$*

dist: monsti bcrypt
	rm -R $(DIST_PATH)
	mkdir -p $(DIST_PATH)/bin
	cp go/bin/* $(DIST_PATH)/bin
	mkdir -p $(DIST_PATH)/share
	cp -RL locale static templates $(DIST_PATH)/share
	mkdir -p $(DIST_PATH)/doc
	cp CHANGES COPYING LICENSE README $(DIST_PATH)/doc
	mkdir -p $(DIST_PATH)/etc
	cp -R example/config/* $(DIST_PATH)/etc
	mv $(DIST_PATH)/etc/sites/example $(DIST_PATH)/etc/sites/default
	mkdir -p $(DIST_PATH)/run
	mkdir -p $(DIST_PATH)/data
	cp -R example/data/example $(DIST_PATH)/data/default
	cp example/start.sh $(DIST_PATH)/
	sed -i 's/\.\.\/go\///' $(DIST_PATH)/start.sh
	sed -i 's/config/etc/' $(DIST_PATH)/start.sh
	tar -C dist -czf dist/monsti-$(MONSTI_VERSION).tar.gz monsti-$(MONSTI_VERSION)

dist-deb: monsti bcrypt
	rm -Rf $(DIST_PATH)
	mkdir -p $(DIST_PATH)/usr/bin
	cp go/bin/* $(DIST_PATH)/usr/bin
	mkdir -p $(DIST_PATH)/usr/share/monsti
	cp -RL static templates $(DIST_PATH)/usr/share/monsti
	cp -RL locale $(DIST_PATH)/usr/share
	rm $(DIST_PATH)/usr/share/locale/*.pot
	mkdir -p $(DIST_PATH)/usr/share/doc/monsti/examples
	cp example/start.sh $(DIST_PATH)/usr/share/doc/monsti/examples
	sed -i 's/\.\.\/go\///' $(DIST_PATH)/usr/share/doc/monsti/examples/start.sh
	sed -i 's/config/etc\/monsti/' $(DIST_PATH)/usr/share/doc/monsti/examples/start.sh
	cp CHANGES COPYING LICENSE README $(DIST_PATH)/usr/share/doc/monsti
	mkdir -p $(DIST_PATH)/etc/monsti/sites
	cp -R example/config/* $(DIST_PATH)/etc/monsti
	sed -i 's/\.\.\/share/\/usr\/share\/monsti/' $(DIST_PATH)/etc/monsti/monsti.yaml
	sed -i 's/\.\.\/data/\/var\/lib\/monsti/' $(DIST_PATH)/etc/monsti/monsti.yaml
	sed -i 's/\.\.\/run/\/var\/run\/monsti/' $(DIST_PATH)/etc/monsti/monsti.yaml
	mv $(DIST_PATH)/etc/monsti/sites/example $(DIST_PATH)/etc/monsti/sites/default
	mkdir -p $(DIST_PATH)/var/run/monsti
	mkdir -p $(DIST_PATH)/var/lib/monsti
	cp -R example/data/example $(DIST_PATH)/var/lib/monsti/default
	find $(DIST_PATH) -type d -exec chmod 755 {} \;
	find $(DIST_PATH) -not -type d -exec chmod 644 {} \;
	chmod 755 $(DIST_PATH)/usr/bin/*
	fpm -s dir -t deb -a all \
		-C $(DIST_PATH) \
		-n monsti \
		-p dist/monsti_$(MONSTI_VERSION)-$(DEB_VERSION).deb \
		--version $(MONSTI_VERSION)-$(DEB_VERSION) \
		etc usr var

go/src/pkg.monsti.org/monsti:
	mkdir -p $(GOPATH)/src/pkg.monsti.org
	ln -sf ../../.. $(GOPATH)/src/pkg.monsti.org/monsti

# Build module executable
.PHONY: $(MODULE_PROGRAMS)
$(MODULE_PROGRAMS): go/bin/monsti-%: go/src/pkg.monsti.org/monsti
	mkdir -p $(GOPATH)/bin
	$(GO_GET) -d pkg.monsti.org/monsti/core/$*
	cd core/$* && $(GO_BUILD) -o $(GOPATH)/bin/monsti-$* .

.PHONY: tests
tests: $(MODULES:%=test-module-%) util/test-template util/test-testing\
	util/test-l10n rpc/test-client

test-module-%:
	cd core/$* && $(GO_TEST) .

test-%:
	$(GO_TEST) pkg.monsti.org/$*

.PHONY: clean
clean:
	rm go/* -Rf
	rm static/aloha/ -Rf
	rm locale/ -Rf
	rm dist/ -Rf
	rm templates/ -Rf

dep-aloha-editor: static/aloha/
static/aloha/:
	wget -nv http://aloha-editor.org/builds/stable/alohaeditor-$(ALOHA_VERSION).zip
	unzip -q alohaeditor-$(ALOHA_VERSION).zip
	mkdir static/aloha
	mv alohaeditor-$(ALOHA_VERSION)/aloha/lib static/aloha
	mv alohaeditor-$(ALOHA_VERSION)/aloha/css static/aloha
	mv alohaeditor-$(ALOHA_VERSION)/aloha/img static/aloha
	mv alohaeditor-$(ALOHA_VERSION)/aloha/plugins static/aloha
	rm alohaeditor-$(ALOHA_VERSION) -R
	rm alohaeditor-$(ALOHA_VERSION).zip

dep-jquery: static/js/jquery.min.js
static/js/jquery.min.js:
	wget -nv http://code.jquery.com/jquery-1.8.2.min.js
	mv jquery-1.8.2.min.js static/js/jquery.min.js
