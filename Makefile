TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

.PHONY: test lint format

test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"

lint:
	@luacheck lua/ --globals vim

format:
	@stylua lua/ plugin/ tests/

format-check:
	@stylua --check lua/ plugin/ tests/