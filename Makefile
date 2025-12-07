BASTILLE_BRANCH=$$(git branch --show-current)
BASTILLE_VERSION=$$(git rev-parse --short HEAD)
BASTILLE_DEV_VERSION="${BASTILLE_BRANCH}-${BASTILLE_VERSION}"

.PHONY: all
all:
	@echo "Nothing to be done. Please use make install or make uninstall"
.PHONY: install
install:
	@echo "Installing Bastille"
	@echo
	@echo "Updating Bastille version to match git revision."
	@echo "BASTILLE_VERSION: ${BASTILLE_DEV_VERSION}"
	@sed -i '' "s|BASTILLE_VERSION=.*|BASTILLE_VERSION=${BASTILLE_DEV_VERSION}|" usr/local/bin/bastille
	@cp -Rv usr /
	@gzip -f -n /usr/local/share/man/man1/bastille*.1
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
	@rm -rvf /usr/local/share/man/man1/bastille*
	@rm -rvf /usr/local/share/man/man5/bastille*
	@echo
	@echo "removing configuration file"
	@rm -rvf /usr/local/etc/bastille/bastille.conf.sample
	@echo
	@echo "removing startup script"
	@rm -vf /usr/local/etc/rc.d/bastille
	@echo "You may need to manually remove /usr/local/etc/bastille/bastille.conf if it is no longer needed."
