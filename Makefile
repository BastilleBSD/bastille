.PHONY: install
install:
	@echo "Installing Bastille"
	@echo
	@cp -av usr /
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
