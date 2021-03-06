HPROGS = hbal hscan hail hspace
MANS = $(HPROGS:%=man/%.1)
MANHTML = $(HPROGS:%=man/%.html)
HALLPROGS = $(HPROGS) test
HSRCS := $(wildcard Ganeti/HTools/*.hs) $(wildcard Ganeti/*.hs)
HDDIR = apidoc
GHC := ghc

DOCS = README.html NEWS.html

HFLAGS = -O2 -Wall -Werror -fwarn-monomorphism-restriction -fwarn-tabs
HEXTRA =

HPCEXCL = --exclude Main --exclude Ganeti.HTools.QC

# Haskell rules

all: $(HPROGS) man

man: $(MANS) $(MANHTML)


$(HALLPROGS): %: %.hs Ganeti/HTools/Version.hs $(HSRCS) Makefile
	$(GHC) --make $(HFLAGS) $(HEXTRA) $@

test live-test: HEXTRA=-fhpc -Wwarn -fno-warn-missing-signatures \
	-fno-warn-monomorphism-restriction -fno-warn-orphans \
	-fno-warn-missing-methods -fno-warn-unused-imports

$(DOCS) : %.html : %
	LANG=en_US.UTF-8 pandoc -f rst -t html -o $@ $<

%.1: %.rst
	LANG=en_US.UTF-8 pandoc -s -f rst -t man -o $@ $<

%.html: %.rst
	LANG=en_US.UTF-8 pandoc -s -f rst -t html -o $@ $<

doc: $(DOCS) Ganeti/HTools/Version.hs
	rm -rf $(HDDIR)/*
	mkdir -p $(HDDIR)/Ganeti/HTools
	HsColour -print-css > $(HDDIR)/Ganeti/hscolour.css
	ln -s ../hscolour.css $(HDDIR)/Ganeti/HTools/hscolour.css
	for file in $(HSRCS); do \
		hfile=`echo $$file|sed 's/\\.hs$$//'`.html; \
		HsColour -css -anchor $$file > $(HDDIR)/$$hfile ; \
	done
	haddock --odir $(HDDIR) --html --ignore-all-exports \
		-t ganeti-htools -p haddock-prologue \
		--source-module="%{MODULE/.//}.html" \
		--source-entity="%{MODULE/.//}.html#%{NAME}" \
		$(filter-out Ganeti/HTools/ExtLoader.hs,$(HSRCS))

maintainer-clean:
	rm -rf $(HDDIR)
	rm -f $(DOCS) TAGS version Ganeti/HTools/Version.hs
	rm -f $(MANS) $(MANHTML)

clean:
	rm -f $(HALLPROGS)
	rm -f *.o *.prof *.ps *.stat *.aux *.hi
	rm -f Ganeti/HTools/Version.hs
	cd Ganeti && rm -f *.o *.prof *.ps *.stat *.aux *.hi
	cd Ganeti/HTools && rm -f *.o *.prof *.ps *.stat *.aux *.hi

regen-version:
	rm -f version
	$(MAKE) version

version:
	if test -d .git; then \
	  git describe > $@; \
	elif test ! -f $@ ; then \
	  echo "Cannot auto-generate $@ file"; exit 1; \
	fi

Ganeti/HTools/Version.hs: Ganeti/HTools/Version.hs.in version
	sed -e "s/%ver%/$$(cat version)/" < $< > $@

dist:
	$(MAKE) maintainer-clean
	$(MAKE) regen-version Ganeti/HTools/Version.hs doc
	$(MAKE) man
	set -e ; \
	VN=$$(sed 's/^v//' < version) ; \
	PFX="ganeti-htools-$$VN" ; \
	ANAME="$$PFX.tar" ; \
	rm -f $$ANAME $$ANAME.gz ; \
	git archive --format=tar --prefix=$$PFX/ HEAD > $$ANAME ; \
	tar -r -f $$ANAME --owner root --group root \
	    --transform="s,^,$$PFX/,S" version apidoc \
	    $(DOCS) $(MANS) $(MANHTML); \
	gzip -v9 $$ANAME ; \
	TMPDIR=$$(mktemp -d) ; \
	tar xzf $$ANAME.gz -C $$TMPDIR; \
	$(MAKE) -C $$TMPDIR/$$PFX; \
	$(MAKE) -C $$TMPDIR/$$PFX clean; \
	$(MAKE) -C $$TMPDIR/$$PFX check; \
	rm -rf $$TMPDIR ; \
	tar tzvf $$ANAME.gz ; \
	sha1sum $$ANAME.gz ; \
	echo "Archive $$ANAME.gz created."

check: test
	rm -f *.tix *.mix
	./test
ifeq ($(T),markup)
	mkdir -p coverage
	hpc markup --destdir=coverage test $(HPCEXCL)
else
	hpc report test $(HPCEXCL)
endif

live-test: all
	rm -f *.tix *.mix
	./live-test.sh
	# combine the tix files
	hpc sum --union $(HPCEXCL) $(addsuffix .tix,$(HPROGS)) \
	  --output=live-test.tix
ifeq ($(T),markup)
	mkdir -p coverage
	hpc markup --destdir=coverage live-test $(HPCEXCL)
else
	hpc report live-test $(HPCEXCL)
endif

tags:
	find -name '*.hs' | xargs hasktags -e

lint:
	hlint -r -u .

.PHONY : all doc maintainer-clean clean dist check tags regen-version man
