# Code Context for LLMs Reference

Strategies for preparing and managing code context for LLM consumption.

## File Chunking Strategies

### Semantic Chunking

Split code by logical boundaries, not arbitrary line counts:

```typescript
interface CodeChunk {
  filePath: string;
  symbolName: string;
  type: 'function' | 'class' | 'interface' | 'module';
  content: string;
  dependencies: string[];
  tokenCount: number;
}

// Chunk by top-level declarations
function chunkBySymbol(ast: AST): CodeChunk[] {
  return ast.declarations.map(decl => ({
    filePath: ast.filePath,
    symbolName: decl.name,
    type: decl.kind,
    content: decl.getText(),
    dependencies: extractImports(decl),
    tokenCount: estimateTokens(decl.getText()),
  }));
}
```

### Chunking Priority

| Content Type | Priority | Rationale |
|-------------|----------|-----------|
| Function being edited | Highest | Direct target |
| Called functions | High | Immediate dependencies |
| Type definitions | High | Compact, high-value |
| Test files | Medium | Shows expected behavior |
| Config files | Medium | Environment context |
| Documentation | Low | Summarize instead |
| Build scripts | Lowest | Rarely relevant |

## Symbol Extraction

### AST-Based Extraction

```typescript
// Extract function signatures without implementations
function extractSignatures(sourceFile: ts.SourceFile): string[] {
  const signatures: string[] = [];

  ts.forEachChild(sourceFile, (node) => {
    if (ts.isFunctionDeclaration(node) && node.name) {
      // Include signature only, not body
      const sig = node.name.text +
        '(' + node.parameters.map(p =>
          `${p.name.getText()}: ${p.type?.getText() ?? 'any'}`
        ).join(', ') + ')' +
        `: ${node.type?.getText() ?? 'void'}`;
      signatures.push(sig);
    }
  });

  return signatures;
}
```

### Interface-First Context

Provide interfaces before implementations for token efficiency:

```typescript
// Include this (compact, defines contract)
interface UserService {
  getUser(id: string): Promise<User>;
  createUser(data: CreateUserDTO): Promise<User>;
  updateUser(id: string, data: UpdateUserDTO): Promise<User>;
  deleteUser(id: string): Promise<void>;
}

// Only include implementation if directly relevant to the task
```

## Dependency Graph for Context

### Building Relevant Context

```typescript
// Walk the dependency graph to find related code
function getRelevantContext(
  targetFile: string,
  depth: number = 2
): Map<string, string> {
  const context = new Map<string, string>();
  const visited = new Set<string>();

  function walk(file: string, currentDepth: number) {
    if (currentDepth > depth || visited.has(file)) return;
    visited.add(file);

    const content = readFile(file);
    const imports = parseImports(content);

    context.set(file, content);

    for (const imp of imports) {
      const resolved = resolveImport(imp, file);
      if (resolved && isProjectFile(resolved)) {
        walk(resolved, currentDepth + 1);
      }
    }
  }

  walk(targetFile, 0);
  return context;
}
```

### Depth Recommendations

| Task | Dependency Depth | Rationale |
|------|-----------------|-----------|
| Bug fix in single function | 1 | Need immediate callers only |
| Refactoring | 2 | Need callers and their callers |
| New feature | 1-2 | Need interfaces and related modules |
| Architecture review | 0 (signatures only) | Breadth over depth |

## Context Window Management

### Token Budget Allocation

```
Total context window: ~128K-200K tokens

Recommended allocation:
├── System prompt:        ~2K tokens (2%)
├── Task description:     ~500 tokens (0.5%)
├── Primary code:         ~8K tokens (6%)
├── Dependencies:         ~4K tokens (3%)
├── Type definitions:     ~2K tokens (1.5%)
├── Examples/tests:       ~2K tokens (1.5%)
├── Reserved for output:  ~4K tokens (3%)
└── Remaining headroom:   ~105K tokens (available)
```

### Progressive Context Loading

```typescript
// Start minimal, expand if needed
async function buildContext(task: Task): Promise<string> {
  // Level 1: Target file + immediate types
  let context = getMinimalContext(task.targetFile);

  if (estimateTokens(context) < task.tokenBudget * 0.5) {
    // Level 2: Add direct dependencies
    context += getDependencyContext(task.targetFile, 1);
  }

  if (estimateTokens(context) < task.tokenBudget * 0.7) {
    // Level 3: Add tests and examples
    context += getTestContext(task.targetFile);
  }

  return truncateToTokenBudget(context, task.tokenBudget);
}
```

### Context Compression Techniques

1. **Type signatures over implementations** — Include interface, skip method bodies
2. **Summary comments** — Replace large files with `// 200-line module that handles X, Y, Z`
3. **Relevant sections only** — Extract specific functions, not entire files
4. **Deduplication** — Don't repeat shared type imports across chunks
5. **Abbreviation** — Replace verbose imports with `// uses: express, pg, redis`

## Common Pitfalls

- **Sending entire codebase**: Overwhelming context reduces quality; select relevant files
- **Missing type context**: LLMs produce better code when types/interfaces are included
- **Flat file dumps**: No structure; group by relevance with section headers
- **Stale context**: Using cached context when files have changed; always read fresh
- **Ignoring tests**: Tests are excellent context — they show expected behavior concisely
- **No token estimation**: Exceeding context window silently truncates important content
