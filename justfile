# Worktree management
#
# Usage:
#   just worktree add <name>     Create a new worktree at ../projectname.worktree/<name>
#   just worktree home           Print the project root path (use: cd $(just worktree home))
#   just worktree remove <name>  Remove the worktree and its branch (with confirmation)

worktree action name='':
    #!/usr/bin/env bash
    set -euo pipefail

    GIT_COMMON=$(git rev-parse --git-common-dir)
    PROJECT_ROOT=$(cd "$GIT_COMMON/.." && pwd)
    PROJECT_NAME=$(basename "$PROJECT_ROOT")
    WORKTREE_PARENT="$PROJECT_ROOT/../${PROJECT_NAME}.worktree"

    case "{{action}}" in
      add)
        if [ -z "{{name}}" ]; then
          echo "Usage: just worktree add <name>" >&2
          exit 1
        fi
        BRANCH="worktree-{{name}}"
        TARGET="$WORKTREE_PARENT/{{name}}"
        mkdir -p "$WORKTREE_PARENT"
        git -C "$PROJECT_ROOT" worktree add -b "$BRANCH" "$TARGET"
        # Symlink justfile so `just` works inside the new worktree
        ln -sf "../../${PROJECT_NAME}/justfile" "$TARGET/justfile"
        echo "✓ Created worktree at $TARGET on branch $BRANCH"
        ;;

      home)
        if [ "$PWD" = "$PROJECT_ROOT" ]; then
          echo "Already at project home: $PROJECT_ROOT"
        else
          echo "$PROJECT_ROOT"
        fi
        ;;

      remove)
        if [ -z "{{name}}" ]; then
          echo "Usage: just worktree remove <name>" >&2
          exit 1
        fi
        BRANCH="worktree-{{name}}"
        TARGET="$WORKTREE_PARENT/{{name}}"
        echo "This will:"
        echo "  • Remove worktree: $TARGET"
        echo "  • Delete branch:   $BRANCH"
        echo ""
        read -rp "Confirm? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          git -C "$PROJECT_ROOT" worktree remove --force "$TARGET"
          git -C "$PROJECT_ROOT" branch -D "$BRANCH"
          echo "✓ Done."
        else
          echo "Aborted."
        fi
        ;;

      *)
        echo "Unknown action: '{{action}}'" >&2
        echo "Usage: just worktree [add|home|remove] [name]" >&2
        exit 1
        ;;
    esac
