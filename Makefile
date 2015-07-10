ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
EXTRACT_FILES=utilities/locales_files.txt
EXTRACT_TO_EN=lib/Erco/I18N/en.po
EXTRACT_TO_FR=lib/Erco/I18N/fr.po
CARTON=carton exec
XGETTEXT=$(CARTON) local/bin/xgettext.pl
REAL_ERCO=script/application
ERCO=script/erco

AGLIO=aglio --full-width
AGLIO_THEME=$(ROOT_DIR)/public/api/jade/erco.jade
API_MD=public/api/api.md
API_HTML=public/api/index.html

locales:
	$(XGETTEXT) -f $(EXTRACT_FILES) -o $(EXTRACT_TO_EN) 2>/dev/null
	$(XGETTEXT) -f $(EXTRACT_FILES) -o $(EXTRACT_TO_FR) 2>/dev/null

doc:
	$(AGLIO) -t $(AGLIO_THEME) -i $(API_MD) -o $(API_HTML)

test:
	pgrep -f exabgp > $(ROOT_DIR)/exa.pid
	$(CARTON) $(REAL_ERCO) test

dev:
	$(CARTON) morbo $(ERCO) --listen http://0.0.0.0:3000
