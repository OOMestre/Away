.PHONY: all test build staging dmg release-beta release-notes clean

all: staging

test:
	swift test

build:
	swift build -c release

staging:
	./scripts/build-staging.sh

dmg: staging
	./scripts/create-dmg.sh "dist/Away Staging.app" "dist/Away-macOS.dmg" "Away Staging"

release-beta:
	./scripts/release-staging-beta.sh

release-notes:
	swift scripts/generate-release-notes.swift

clean:
	rm -rf .build dist

worktree-add:
	./scripts/manage-worktrees.sh add $(NAME) $(BRANCH)

worktree-list:
	./scripts/manage-worktrees.sh list

worktree-remove:
	./scripts/manage-worktrees.sh remove $(NAME)
