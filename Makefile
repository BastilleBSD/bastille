.PHONY: all
all:
	@echo "Nothing to be done. Please use make install or make uninstall"
.PHONY: install
install:
	@echo "Installing Bastille"
	@echo
	@cp -av usr /
	@chmod 0750 /usr/local/bastille
	@echo
	@echo "This method is for testing / development."

.PHONY: uninstall
uninstall:
	@echo "Removing Bastille command"
	@rm -vf /usr/local/bin/bastille
	@echo
	@echo "Removing Bastille sub-commands"
	@rm -rvf /usr/local/share/bastille
	@echo
	@echo "removing configuration file"
	@rm -rvf /usr/local/etc/bastille
	@echo
	@echo "removing startup script"
	@rm -vf /usr/local/etc/rc.d/bastille
