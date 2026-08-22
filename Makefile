BASTILLE_BRANCH=$$(git branch --show-current)
BASTILLE_VERSION=$$(git rev-parse --short HEAD)
BASTILLE_DEV_VERSION="${BASTILLE_BRANCH}-${BASTILLE_VERSION}"

.PHONY: all
all:
	@echo "Nothing to be done. Please use make install or make uninstall"

# Fast, host-agnostic unit tests (shellspec). No root, no jails, no FreeBSD
# required -- runs on any machine with /bin/sh. See tests/README.md.
.PHONY: test test-unit
test: test-unit
test-unit:
	@command -v shellspec >/dev/null 2>&1 || { \
	  echo "shellspec not found."; \
	  echo "Install it, then re-run 'make test-unit':"; \
	  echo "  Any OS: curl -fsSL https://raw.githubusercontent.com/shellspec/shellspec/master/install.sh | sh"; \
	  echo "  macOS Homebrew: brew install shellspec"; \
	  echo "  Docs: https://github.com/shellspec/shellspec#installation"; \
	  exit 1; }
	@shellspec

.PHONY: install
install:
	@echo "Installing Bastille"
	@echo
	@echo "Updating Bastille version to match git revision."
	@echo "BASTILLE_VERSION: ${BASTILLE_DEV_VERSION}"
	@sed -i '' "s|BASTILLE_VERSION=.*|BASTILLE_VERSION=${BASTILLE_DEV_VERSION}|" usr/local/bin/bastille
	@cp -Rv usr /
	@gzip -f -n /usr/local/share/man/man8/bastille*.8
	@gzip -f -n /usr/local/share/man/man5/bastille*.5
	@echo
	@echo "This method is for testing & development."
	@echo "Please report any issues to https://github.com/BastilleBSD/bastille/issues"

.PHONY: uninstall
uninstall:
	@echo "Removing Bastille command"
	@rm -vf /usr/local/bin/bastille
	@echo
	@echo "Removing Bastille sub-commands"
	@rm -rvf /usr/local/share/bastille
	@echo
	@echo "removing man page"
	@rm -rvf /usr/local/share/man/man8/bastille*
	@rm -rvf /usr/local/share/man/man5/bastille*
	@echo
	@echo "removing configuration file"
	@rm -rvf /usr/local/etc/bastille/bastille.conf.sample
	@echo
	@echo "removing startup script"
	@rm -vf /usr/local/etc/rc.d/bastille
	@echo "You may need to manually remove /usr/local/etc/bastille/bastille.conf if it is no longer needed."
