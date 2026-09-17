.PHONY: initialise setup preflight demo reset cleanup

initialise:
	@echo "Initialising pre-commit hooks"
	pre-commit --version || brew install pre-commit
	pre-commit install --install-hooks
	pre-commit run -a

setup:
	./setup.sh

preflight:
	./preflight.sh

demo:
	./demo.sh

reset:
	./reset.sh

cleanup:
	./cleanup.sh
