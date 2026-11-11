_clean:
	rm -rf out/$(BUILD_DIR)
	mkdir -p out/$(BUILD_DIR)/control
	mkdir -p out/$(BUILD_DIR)/data

# geodns-helper (nfqws2-helper модуля nfqws2-android-ext) — под каждую
# архитектуру; MIPS роутеров без FPU — softfloat
.PHONY: _helper
_helper:
	mkdir -p out/helper
	cd helper && CGO_ENABLED=0 GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -trimpath -ldflags "-s -w" -o ../out/helper/geodns-helper-mipsel .
	cd helper && CGO_ENABLED=0 GOOS=linux GOARCH=mips GOMIPS=softfloat go build -trimpath -ldflags "-s -w" -o ../out/helper/geodns-helper-mips .
	cd helper && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" -o ../out/helper/geodns-helper-aarch64 .
	cd helper && CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -trimpath -ldflags "-s -w" -o ../out/helper/geodns-helper-armv7 .

_conffiles:
	cp common/ipk/conffiles out/$(BUILD_DIR)/control/conffiles

_control:
	echo "Package: keenetic-geodns" > out/$(BUILD_DIR)/control/control
	echo "Version: $(VERSION)" >> out/$(BUILD_DIR)/control/control
	echo "Depends: dnsmasq-full, https-dns-proxy, curl, ca-bundle" >> out/$(BUILD_DIR)/control/control
	echo "License: MIT" >> out/$(BUILD_DIR)/control/control
	echo "Section: net" >> out/$(BUILD_DIR)/control/control
	echo "URL: https://github.com/SpectaCoolAre/keenetic-geodns" >> out/$(BUILD_DIR)/control/control
	echo "Architecture: $(ARCH)" >> out/$(BUILD_DIR)/control/control
	echo "Description:  Geoblock bypass via DNS (same server choice as nfqws2-android-ext)" >> out/$(BUILD_DIR)/control/control
	echo "" >> out/$(BUILD_DIR)/control/control

_scripts:
	cp common/ipk/preinst common/ipk/postinst common/ipk/prerm common/ipk/postrm out/$(BUILD_DIR)/control/
	chmod +x out/$(BUILD_DIR)/control/preinst out/$(BUILD_DIR)/control/postinst out/$(BUILD_DIR)/control/prerm out/$(BUILD_DIR)/control/postrm

_binary:
	cp out/helper/geodns-helper-$(BIN) out/$(BUILD_DIR)/data$(ROOT_DIR)/bin/geodns-helper
	chmod +x out/$(BUILD_DIR)/data$(ROOT_DIR)/bin/geodns-helper

_binary-multi:
	mkdir -p out/$(BUILD_DIR)/data$(ROOT_DIR)/tmp/geodns_binary
	cp out/helper/geodns-helper-* out/$(BUILD_DIR)/data$(ROOT_DIR)/tmp/geodns_binary/
	chmod +x out/$(BUILD_DIR)/data$(ROOT_DIR)/tmp/geodns_binary/*

_ipk:
	make _clean

	# control.tar.gz
	make _conffiles
	make _control
	make _scripts
	cd out/$(BUILD_DIR)/control; tar czvf ../control.tar.gz .; cd ../../..

	# data.tar.gz
	mkdir -p out/$(BUILD_DIR)/data$(ROOT_DIR)/bin
	mkdir -p out/$(BUILD_DIR)/data$(ROOT_DIR)/var/log
	mkdir -p out/$(BUILD_DIR)/data$(ROOT_DIR)/var/run
	mkdir -p out/$(BUILD_DIR)/data$(ROOT_DIR)/etc/init.d

	cp -r etc/geodns out/$(BUILD_DIR)/data$(ROOT_DIR)/etc/geodns
	cp etc/init.d/S55geodns out/$(BUILD_DIR)/data$(ROOT_DIR)/etc/init.d/S55geodns
	chmod +x out/$(BUILD_DIR)/data$(ROOT_DIR)/etc/init.d/S55geodns
	cp bin/geodns out/$(BUILD_DIR)/data$(ROOT_DIR)/bin/geodns
	chmod +x out/$(BUILD_DIR)/data$(ROOT_DIR)/bin/geodns

	@if [[ "$(BUILD_DIR)" == "all" ]]; then \
		make _binary-multi; \
	else \
		make _binary; \
	fi

	cd out/$(BUILD_DIR)/data; tar czvf ../data.tar.gz .; cd ../../..

	# ipk
	echo 2.0 > out/$(BUILD_DIR)/debian-binary
	cd out/$(BUILD_DIR); \
	tar czvf ../$(FILENAME) control.tar.gz data.tar.gz debian-binary; \
	cd ../..

mipsel: _helper
	@make \
		BUILD_DIR=mipsel \
		ARCH=mipsel-3.4 \
		FILENAME=keenetic-geodns_$(VERSION)_mipsel-3.4.ipk \
		BIN=mipsel \
		_ipk

mips: _helper
	@make \
		BUILD_DIR=mips \
		ARCH=mips-3.4 \
		FILENAME=keenetic-geodns_$(VERSION)_mips-3.4.ipk \
		BIN=mips \
		_ipk

aarch64: _helper
	@make \
		BUILD_DIR=aarch64 \
		ARCH=aarch64-3.10 \
		FILENAME=keenetic-geodns_$(VERSION)_aarch64-3.10.ipk \
		BIN=aarch64 \
		_ipk

armv7: _helper
	@make \
		BUILD_DIR=armv7 \
		ARCH=armv7-3.2 \
		FILENAME=keenetic-geodns_$(VERSION)_armv7-3.2.ipk \
		BIN=armv7 \
		_ipk

multi: _helper
	@make \
		BUILD_DIR=all \
		ARCH=all \
		FILENAME=keenetic-geodns_$(VERSION)_all_entware.ipk \
		_ipk

packages: mipsel mips aarch64 armv7 multi
