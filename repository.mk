_repo-clean:
	rm -rf out/_pages/$(BUILD_DIR)
	mkdir -p out/_pages/$(BUILD_DIR)

_repo-copy:
	cp "out/$(FILENAME)" "out/_pages/$(BUILD_DIR)/"

_repo-html:
	echo '<html><head><title>keenetic-geodns repository</title></head><body>' > out/_pages/$(BUILD_DIR)/index.html
	echo '<h1>Index of /$(BUILD_DIR)/</h1><hr>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<pre>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<a href="../">../</a>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<a href="Packages">Packages</a>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<a href="Packages.gz">Packages.gz</a>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<a href="$(FILENAME)">$(FILENAME)</a>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '</pre>' >> out/_pages/$(BUILD_DIR)/index.html
	echo '<hr></body></html>' >> out/_pages/$(BUILD_DIR)/index.html

_repo-index:
	echo '<html><head><title>keenetic-geodns repository</title></head><body>' > out/_pages/index.html
	echo '<h1>Index of /</h1><hr>' >> out/_pages/index.html
	echo '<pre>' >> out/_pages/index.html
	echo '<a href="all/">all/</a>' >> out/_pages/index.html
	echo '<a href="aarch64/">aarch64/</a>' >> out/_pages/index.html
	echo '<a href="armv7/">armv7/</a>' >> out/_pages/index.html
	echo '<a href="mips/">mips/</a>' >> out/_pages/index.html
	echo '<a href="mipsel/">mipsel/</a>' >> out/_pages/index.html
	echo '</pre>' >> out/_pages/index.html
	echo '<hr></body></html>' >> out/_pages/index.html

_repository:
	make _repo-clean
	make _repo-copy

	echo "Package: keenetic-geodns" > out/_pages/$(BUILD_DIR)/Packages
	echo "Version: $(VERSION)" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Depends: dnsmasq-full, https-dns-proxy, curl, ca-bundle" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Section: net" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Architecture: $(ARCH)" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Filename: $(FILENAME)" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Size: $(shell wc -c out/$(FILENAME) | awk '{print $$1}')" >> out/_pages/$(BUILD_DIR)/Packages
	echo "SHA256sum: $(shell sha256sum out/$(FILENAME) | awk '{print $$1}')" >> out/_pages/$(BUILD_DIR)/Packages
	echo "Description:  Geoblock bypass via DNS (same server choice as nfqws2-android-ext)" >> out/_pages/$(BUILD_DIR)/Packages
	echo "" >> out/_pages/$(BUILD_DIR)/Packages

	gzip -k out/_pages/$(BUILD_DIR)/Packages

	@make _repo-html

repo-mipsel:
	@make \
		BUILD_DIR=mipsel \
		ARCH=mipsel-3.4 \
		FILENAME=keenetic-geodns_$(VERSION)_mipsel-3.4.ipk \
		_repository

repo-mips:
	@make \
		BUILD_DIR=mips \
		ARCH=mips-3.4 \
		FILENAME=keenetic-geodns_$(VERSION)_mips-3.4.ipk \
		_repository

repo-aarch64:
	@make \
		BUILD_DIR=aarch64 \
		ARCH=aarch64-3.10 \
		FILENAME=keenetic-geodns_$(VERSION)_aarch64-3.10.ipk \
		_repository

repo-armv7:
	@make \
		BUILD_DIR=armv7 \
		ARCH=armv7-3.2 \
		FILENAME=keenetic-geodns_$(VERSION)_armv7-3.2.ipk \
		_repository

repo-multi:
	@make \
		BUILD_DIR=all \
		ARCH=all \
		FILENAME=keenetic-geodns_$(VERSION)_all_entware.ipk \
		_repository

repository: repo-mipsel repo-mips repo-aarch64 repo-armv7 repo-multi _repo-index
