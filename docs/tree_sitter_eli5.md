# Tree-sitter: ELI5

## What Is Tree-sitter?

Imagine you're reading a book, but instead of just seeing words on a page, you can see the **structure** of the book too. You can see where chapters start, where paragraphs begin, where sentences end. That's what Tree-sitter does for code.

## The Problem It Solves

When you write code, your editor needs to understand it. Not just display it, but actually **understand** it. Your editor needs to know:

* "This is a function"
* "This is a variable name"
* "This is a string"
* "This function starts here and ends there"

Without this understanding, your editor can't:
* Color-code your code (syntax highlighting)
* Help you navigate (jump to function definitions)
* Refactor code (rename variables safely)
* Show you errors before you run the code

## How It Works (Simple Version)

Tree-sitter reads your code and builds a **tree** of what it means.

Think of it like this: if your code is a sentence, Tree-sitter figures out:
* What's the subject? (the function name)
* What's the verb? (what the function does)
* What are the objects? (the parameters, the body)

For code, it figures out:
* What's a function?
* What's inside that function?
* What are the variables?
* Where do things start and end?

## The Tree Structure

Tree-sitter creates a tree (like a family tree, but for code):

```
Source File
├── Function: main()
│   ├── Parameter: void
│   └── Body
│       ├── Call: print()
│       └── String: "Hello"
└── Function: helper()
    └── Body
        └── Return statement
```

Each part of your code becomes a **node** in this tree. Nodes know:
* What they are (function, variable, string, etc.)
* Where they start (line 5, column 10)
* Where they end (line 8, column 3)
* What's inside them (their children)

## Why We Need It

### 1. Syntax Highlighting

Your editor needs to know "this is a function name" so it can color it blue, or "this is a string" so it can color it green. Tree-sitter tells the editor what each piece of code is.

### 2. Navigation

You want to jump to a function definition? Tree-sitter knows where it is. You want to see all functions in a file? Tree-sitter can list them.

### 3. Refactoring

You want to rename a variable? Tree-sitter knows all the places that variable is used, so it can rename them all safely.

### 4. Error Detection

Tree-sitter can catch some errors before you even run your code. Like "you forgot to close this bracket" or "this variable doesn't exist here."

## How We're Using It

In our Dream Editor, Tree-sitter helps us:

1. **Parse Zig code** - Understand what the code means
2. **Highlight syntax** - Color-code different parts
3. **Navigate structure** - Jump to functions, find definitions
4. **Enable code actions** - Extract functions, rename symbols
5. **Support folding** - Know where function bodies are so we can fold them

## The Abstraction We Built

We created `aurora_tree_sitter.zig` which is a **wrapper** around Tree-sitter. Right now it's a simple version that uses regex to find functions and structs. Later, we'll connect it to the real Tree-sitter C library.

Think of it like this:
* **Tree-sitter C library** = The engine (does the hard parsing work)
* **Our Zig wrapper** = The steering wheel (gives us a nice interface to use it)

## Current Implementation

Right now, our implementation:
* Parses Zig code to find functions and structs
* Creates a tree structure with nodes
* Lets you find nodes at specific positions (like where your cursor is)
* Is simple but works for basic needs

Later, we'll:
* Connect to the real Tree-sitter C library
* Use the official Zig grammar
* Get full syntax highlighting
* Enable advanced code actions

## Why Start Simple?

We're building incrementally. First, we get the structure working with simple parsing. Then we add the real Tree-sitter library. This way, we can test and use the editor features while we work on the full integration.

It's like building a house: first you put up the frame (our simple parser), then you add the plumbing and electricity (the full Tree-sitter integration).

## The Bottom Line

Tree-sitter helps your editor **understand** your code, not just display it. It's the difference between a text editor (shows words) and a code editor (understands structure).

We're building our own abstraction so we can use Tree-sitter in a way that fits our GrainStyle principles: explicit, bounded, and clear.

