# Conflict Resolution Reference

Comprehensive guide to resolving git merge, rebase, and cherry-pick conflicts.

---

## Conflict Types

### Content Conflicts

**Occur when**: Same lines modified in both branches.

**Example**:
```
<<<<<<< HEAD
const API_URL = 'https://api.example.com';
=======
const API_URL = 'https://api.staging.example.com';
>>>>>>> feature-branch
```

**Resolution**: Choose one, combine both, or write new solution.

### File Rename Conflicts

**Occur when**: File renamed in one branch, modified in another.

**Example**:
```
CONFLICT (rename/modify): old-name.txt renamed to new-name.txt in HEAD, modified in feature-branch
```

**Resolution**:
```bash
# Accept rename and apply modifications
git add new-name.txt
git rm old-name.txt
```

### File Deletion Conflicts

**Occur when**: File deleted in one branch, modified in another.

**Example**:
```
CONFLICT (modify/delete): file.txt deleted in HEAD and modified in feature-branch
```

**Resolution**:
```bash
# Keep deletion
git rm file.txt

# Or keep modification
git add file.txt
```

### Directory Conflicts

**Occur when**: Directory becomes file or vice versa.

**Example**:
```
CONFLICT: directory/file exists as directory in one branch, file in another
```

**Resolution**: Complex, usually requires manual intervention and restructuring.

---

## Resolution Decision Tree

```
Conflict occurred?
  ↓
1. Understand both versions
  ↓
2. Determine intent of each change
  ↓
3. Decide resolution strategy:
  ↓
  ├─ Both changes needed? → Combine
  ├─ Ours is correct? → Keep ours
  ├─ Theirs is correct? → Keep theirs
  ├─ Both wrong? → Write new solution
  └─ Unsure? → Ask other developer
  ↓
4. Test resolution
  ↓
5. Commit with descriptive message
```

---

## Resolution Strategies

### Strategy 1: Manual Combination

**Best for**: Both changes are valuable and can coexist.

**Example conflict**:
```javascript
<<<<<<< HEAD
function authenticate(username, password) {
  return bcrypt.compare(password, user.hash);
}
=======
function authenticate(username, password, token) {
  return jwt.verify(token, secret);
}
>>>>>>> feature-branch
```

**Resolution** (combine both):
```javascript
function authenticate(username, password, token = null) {
  if (token) {
    return jwt.verify(token, secret);
  }
  return bcrypt.compare(password, user.hash);
}
```

### Strategy 2: Accept Ours

**Best for**: Current branch has the correct version.

```bash
# For single file
git checkout --ours file.txt
git add file.txt

# For multiple files
git checkout --ours .
git add .

# During merge
git merge --strategy-option ours feature-branch
```

**Use cases**:
- Incoming changes are experimental
- Current branch is production, incoming is outdated
- Merge is just to close branch (rare)

### Strategy 3: Accept Theirs

**Best for**: Incoming branch has the correct version.

```bash
# For single file
git checkout --theirs file.txt
git add file.txt

# For multiple files
git checkout --theirs .
git add .

# During merge
git merge --strategy-option theirs feature-branch
```

**Use cases**:
- Updating feature branch from main
- Accepting upstream changes
- Current changes are experimental

### Strategy 4: Use Merge Tool

**Best for**: Complex conflicts with many files.

```bash
# Launch configured merge tool
git mergetool

# Configure merge tool (one-time)
git config --global merge.tool <tool>
# Options: vimdiff, meld, kdiff3, opendiff, bc3, p4merge
```

**Meld example** (GUI):
```bash
# Install meld
sudo apt install meld  # Linux
brew install meld      # macOS

# Configure
git config --global merge.tool meld

# Use
git mergetool
```

**Vimdiff example** (terminal):
```bash
# Configure
git config --global merge.tool vimdiff
git config --global mergetool.vimdiff.cmd 'vimdiff "$LOCAL" "$MERGED" "$REMOTE"'

# Use (opens 3-way diff)
git mergetool

# In vimdiff:
# :diffget LOCAL    (get from our version)
# :diffget REMOTE   (get from their version)
# :wqa              (save and quit)
```

---

## Common Conflict Patterns

### Pattern 1: Whitespace Conflicts

**Conflict**:
```
<<<<<<< HEAD
const x = 1;
=======
const x = 1;
>>>>>>> feature-branch
```
*(Note: trailing space on second version)*

**Resolution**:
```bash
# Ignore whitespace during merge
git merge -X ignore-space-change feature-branch

# Or rebase
git rebase -X ignore-space-change main
```

### Pattern 2: Import Statement Conflicts

**Conflict**:
```javascript
<<<<<<< HEAD
import { foo, bar } from './module';
=======
import { foo, baz } from './module';
>>>>>>> feature-branch
```

**Resolution** (combine):
```javascript
import { foo, bar, baz } from './module';
```

### Pattern 3: Configuration Conflicts

**Conflict**:
```json
<<<<<<< HEAD
{
  "timeout": 3000
}
=======
{
  "timeout": 5000
}
>>>>>>> feature-branch
```

**Resolution** (investigate why different):
- Check commit messages
- Ask other developer
- Consider environment-specific config

### Pattern 4: Dependency Version Conflicts

**Conflict in package.json**:
```json
<<<<<<< HEAD
"lodash": "^4.17.20"
=======
"lodash": "^4.17.21"
>>>>>>> feature-branch
```

**Resolution**:
```json
"lodash": "^4.17.21"  // Use latest
```

Then regenerate lock file:
```bash
npm install
git add package.json package-lock.json
```

---

## Rebase Conflict Resolution

### Rebase Workflow

```bash
# Start rebase
git rebase main

# If conflict:
# 1. View conflicted files
git status

# 2. Resolve conflicts (edit files)

# 3. Stage resolved files
git add .

# 4. Continue rebase
git rebase --continue

# Or skip this commit
git rebase --skip

# Or abort entire rebase
git rebase --abort
```

### Multiple Conflicts During Rebase

**Scenario**: Rebase has conflicts in multiple commits.

```bash
# Rebase applies commits one-by-one
git rebase main

# Conflict in commit 1
# Fix, then:
git add .
git rebase --continue

# Conflict in commit 2
# Fix, then:
git add .
git rebase --continue

# ...until rebase completes
```

**Tip**: If too many conflicts, consider merge instead of rebase.

---

## Cherry-Pick Conflict Resolution

```bash
# Cherry-pick commit
git cherry-pick abc123

# If conflict:
# 1. Resolve conflicts

# 2. Stage files
git add .

# 3. Continue cherry-pick
git cherry-pick --continue

# Or abort
git cherry-pick --abort
```

---

## Testing After Resolution

**Critical**: Always test after resolving conflicts.

```bash
# Run tests
npm test

# Or project-specific tests
make test
pytest
cargo test

# Manual smoke test
npm start
# Check app works
```

**Common post-resolution bugs**:
- Syntax errors from incomplete resolution
- Logic errors from incorrect combination
- Missing imports from partial resolution
- Broken functionality from conflicting features

---

## Aborting Operations

### Abort Merge

```bash
git merge --abort

# Returns to pre-merge state
```

**Use when**: Conflict is too complex, need to rethink approach.

### Abort Rebase

```bash
git rebase --abort

# Returns to pre-rebase state
```

**Use when**: Too many conflicts, prefer merge instead.

### Abort Cherry-Pick

```bash
git cherry-pick --abort

# Returns to pre-cherry-pick state
```

---

## Advanced Resolution Techniques

### Three-Way Merge Markers

```bash
# Enable three-way merge markers
git config --global merge.conflictStyle diff3

# Conflict now shows:
<<<<<<< HEAD
Our version
||||||| base
Original version
=======
Their version
>>>>>>> feature-branch
```

**Benefit**: See original version to understand changes better.

### Recursive Merge Strategy

```bash
# Use recursive strategy (default, but configurable)
git merge -s recursive feature-branch

# With options:
git merge -s recursive -X ours feature-branch  # Favor our changes
git merge -s recursive -X theirs feature-branch  # Favor their changes
```

### Octopus Merge

```bash
# Merge multiple branches at once
git merge branch1 branch2 branch3

# Requires no conflicts
```

**Use case**: Integrating multiple independent features simultaneously.

---

## Conflict Prevention

### Keep Branches Updated

```bash
# Regularly update feature branch from main
git checkout feature-branch
git merge main
# Or
git rebase main

# Prevents large conflicts at end
```

### Small, Focused Commits

```bash
# Good: Small, atomic commits
git commit -m "feat: add user model"
git commit -m "feat: add user controller"

# Bad: Large, monolithic commit
git commit -m "feat: add entire user system"
```

**Benefit**: Easier to resolve conflicts commit-by-commit.

### Communicate with Team

- **Before large refactor**: Notify team to avoid conflicting work
- **During development**: Coordinate on shared files
- **After conflict**: Document resolution reasoning

### Use Feature Flags

```javascript
// Avoid conflicts by using feature flags
if (featureFlags.newAuth) {
  return jwt.authenticate(token);
} else {
  return bcrypt.authenticate(password);
}
```

**Benefit**: Both implementations can coexist temporarily.

---

## Conflict Resolution Tools

### Command-Line Tools

| Tool | Type | Best For |
|------|------|----------|
| `vimdiff` | Terminal | Keyboard-driven workflow |
| `git-cola` | GUI | Simple visual conflicts |
| `tig` | Terminal | History browsing + resolution |

### GUI Tools

| Tool | Platform | Best For |
|------|----------|----------|
| Meld | Linux/macOS/Windows | 3-way diff clarity |
| KDiff3 | Linux/macOS/Windows | Directory merges |
| Beyond Compare | macOS/Windows (paid) | Professional use |
| P4Merge | macOS/Windows/Linux | Free, powerful |
| Sourcetree | macOS/Windows | All-in-one Git GUI |
| GitKraken | macOS/Windows/Linux | Modern UI |

### IDE Integration

| IDE | Built-in Support |
|-----|------------------|
| VSCode | Excellent (color-coded, click to resolve) |
| IntelliJ IDEA | Excellent (3-way merge UI) |
| Vim | Via fugitive plugin |
| Emacs | Via magit |

---

## Commit Message After Resolution

```bash
# Merge commit message should explain resolution
git commit -m "$(cat <<'EOF'
Merge branch 'feature/auth' into main

Resolved conflicts in:
- src/auth.js: Combined JWT and bcrypt authentication
- package.json: Updated lodash to latest version
- tests/auth.test.js: Merged test cases from both branches

All tests passing after resolution.
EOF
)"
```

---

**Last Updated**: 2026-02-16
