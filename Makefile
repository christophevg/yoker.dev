YOKER=uv run --with ../yoker yoker

all: yoker-chat

init: yoker.toml

yoker-chat: yoker.toml
	@$(YOKER) chat

yoker.toml:
	@echo "*** initializing yoker.toml"
	@$(YOKER) init --path ./yoker.toml
