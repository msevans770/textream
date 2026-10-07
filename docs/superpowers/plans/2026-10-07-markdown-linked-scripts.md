# Markdown Linked Scripts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let Textream (macOS) link to a `.md` / `.markdown` / `.txt` file and, each time Play is pressed, re-read it, strip Markdown to speakable text, split it into pages, and prompt from that, with no intermediate files.

**Architecture:** A Foundation-only `MarkdownScriptParser` turns source text into `[String]` pages. A Foundation-only `LinkedScriptStore` reads a file (security-scoped bookmark aware) and parses it. `TextreamService` holds the link state (`linkedScriptURL`, `linkedScriptWarning`), re-reads on Play, and persists the link as a bookmark. `ContentView` shows a "Linked to …" banner, makes the editor read-only while linked, and accepts `.md`/`.txt` drops. The two Foundation-only files are unit-tested through a small SwiftPM package (the Xcode project has no macOS test target).

**Tech Stack:** Swift 6 / SwiftUI / AppKit, Foundation `NSRegularExpression`, XCTest via SwiftPM, Xcode 27 (`xcodebuild`).

**Spec:** Decisions agreed with the user in conversation on 2026-10-07 (no separate spec file). They are restated in "Global Constraints" below.

## Global Constraints

- macOS target only. Do **not** touch anything under `Textream/TextreamiOS/` or `Textream/TextreamiOSTests/`.
- Work in `/Users/user/Developer/textream` on branch `feature/markdown-linked-scripts`. New commits, never amends. **Never push.** Subagents do **not** commit. The overseer commits after reviewing each task.
- New app files go in `Textream/Textream/` (Xcode uses synchronized folders, so they are auto-included in the app target). Do not edit `project.pbxproj`.
- The two Foundation-only files (`MarkdownScriptParser.swift`, `LinkedScriptStore.swift`) must import only `Foundation` (no AppKit/SwiftUI) so SwiftPM can compile them.
- Page splitting: a horizontal rule line (`---`, `***`, `___`, spaced variants) **or** an ATX heading line (`#`–`######`) starts a new page. Heading text is kept as spoken text with the `#`s removed.
- Strip: frontmatter, fenced code blocks (contents included), `<!-- -->` comments, `%% %%` Obsidian comments, images `![](…)`, embeds `![[…]]`, footnote refs/defs, HTML tags, emphasis markers, inline-code backticks, list/task/blockquote/callout markers. `[text](url)` becomes `text`. `[[Page|Alias]]` becomes `Alias`, `[[Page#Heading]]` becomes `Page`. Tables flatten to cell text joined by single spaces, one row per line.
- Keep teleprompter cue brackets such as `[pause]`, `[smile]` exactly as written. The app depends on them (`HighlightingTextEditor` italicises them and `SpeechRecognizer` auto-skips them).
- `.txt` files: no Markdown stripping and no heading splitting. Only `---` rule lines split pages.
- Linked mode: editor is read-only; Add Page, Delete Page and the dictation mic are disabled; an **Unlink** button turns the pages into normal editable pages. Save / Save As while linked writes a `.textream` snapshot and must **never** write to or replace the `.md` file, and must not unlink.
- Re-read only when Play starts (and when linking). Never reload while the prompter is running. No file watcher in v1.
- If the linked file is missing, unreadable or yields zero pages on re-read: keep the last good pages, set `linkedScriptWarning`, and still play. Never play a blank script.
- The link persists across relaunch via a security-scoped bookmark in `UserDefaults` (app is sandboxed with `com.apple.security.files.user-selected.read-write`).
- British English in all user-facing strings and comments. Match the surrounding code's comment density and idiom.

## Review Focus

1. **Cue brackets vs links** — `[pause] see [docs](http://x) [smile]` must become `[pause] see docs [smile]` (Task 1 test `testCueNextToLinkPreserved`).
2. **File changes between plays** — linked file deleted, moved, emptied or made unreadable: prompter still plays the last good pages and a warning shows (Task 2 tests `testLoadPagesEmptyFileThrowsEmpty`, `testLoadPagesMissingFileThrows`; Task 4 `refreshLinkedScript` keeps pages on failure).
3. **Ordinary prose is not mangled** — `my_var_name`, `2*3*4`, `Issue #5`, `#tag` must pass through untouched (Task 1 tests).
4. **Save never clobbers the `.md`** — Save / Save As while linked writes JSON only to a `.textream` file the user chose (Task 4 `saveToURL` change, checked in Task 7 manual checklist).
5. **Odd inputs** — CRLF, BOM, unclosed frontmatter, unclosed code fence, non-UTF-8 file, link page count shrinking below `currentPageIndex` (Tasks 1, 2, 4).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `Textream/Package.swift` | Create | SwiftPM harness compiling the two Foundation-only files for tests |
| `Textream/MarkdownScriptTests/MarkdownScriptParserTests.swift` | Create | Parser tests |
| `Textream/MarkdownScriptTests/LinkedScriptStoreTests.swift` | Create | Store tests |
| `Textream/Textream/MarkdownScriptParser.swift` | Create | `MarkdownScriptParser.parse(_:isPlainText:) -> [String]` |
| `Textream/Textream/LinkedScriptStore.swift` | Create | Bookmark + file reading + parsing |
| `Textream/Textream/HighlightingTextEditor.swift` | Modify | `isEditable` parameter |
| `Textream/Textream/TextreamService.swift` | Modify | Link state, router, link/refresh/unlink/restore, panel types, save guard |
| `Textream/Textream/ContentView.swift` | Modify | Banner, read-only editor, disabled controls, drop handler, Play refresh, restore on appear |
| `Textream/Textream/TextreamApp.swift` | Modify | Route Finder-open / `onOpenURL` through the router |
| `Textream/Info.plist` | Modify | Register `.md`/`.markdown`/`.txt` as Alternate-rank openable documents |
| `.gitignore` | Modify | Ignore `Textream/.build/` |

## Wave plan (overseer runs this)

- **Task 0** (overseer, serial): branch + scaffold, so parallel tasks never collide on shared files.
- **Wave 1** (parallel, haiku): Task 1 parser, Task 2 store, Task 3 editor flag. Disjoint files.
- **Wave 2** (serial): Task 4 service. Needs Tasks 2 and 3 merged.
- **Wave 3** (parallel, haiku): Task 5 ContentView, Task 6 App + Info.plist. Disjoint files; both need Task 4's interface.
- **Task 7** (overseer): full build, SwiftPM tests, manual checklist, whole-branch review.

---

### Task 0: Branch and SwiftPM scaffold (overseer)

**Files:**
- Create: `Textream/Package.swift`, stub `Textream/Textream/MarkdownScriptParser.swift`, stub `Textream/Textream/LinkedScriptStore.swift`, stub test files
- Modify: `.gitignore`

**Interfaces:**
- Produces (stubs that later tasks replace, with these exact signatures):
  - `enum MarkdownScriptParser { static func parse(_ source: String, isPlainText: Bool = false) -> [String] }`
  - `enum LinkedScriptError: Error, LocalizedError { case bookmarkInvalid; case unreadable(String); case empty }`
  - `enum LinkedScriptStore { static func makeBookmark(for url: URL) throws -> Data; static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool); static func loadPages(from url: URL) throws -> [String] }`

- [ ] **Step 1: Create the branch**

```bash
cd /Users/user/Developer/textream && /usr/bin/git checkout -b feature/markdown-linked-scripts
```

- [ ] **Step 2: Write `Textream/Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

// Test harness only: compiles the two Foundation-only source files from the app
// so they can be unit-tested with `swift test` (the Xcode project has no macOS test target).
let package = Package(
    name: "MarkdownScript",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MarkdownScript",
            path: "Textream",
            sources: ["MarkdownScriptParser.swift", "LinkedScriptStore.swift"]
        ),
        .testTarget(
            name: "MarkdownScriptTests",
            dependencies: ["MarkdownScript"],
            path: "MarkdownScriptTests"
        ),
    ]
)
```

- [ ] **Step 3: Write the stubs**

`Textream/Textream/MarkdownScriptParser.swift`:
```swift
import Foundation

enum MarkdownScriptParser {
    /// Converts Markdown (or plain text) into teleprompter pages.
    static func parse(_ source: String, isPlainText: Bool = false) -> [String] {
        return []
    }
}
```

`Textream/Textream/LinkedScriptStore.swift`:
```swift
import Foundation

enum LinkedScriptError: Error, LocalizedError {
    case bookmarkInvalid
    case unreadable(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .bookmarkInvalid: return "The link to the script file is no longer valid."
        case .unreadable(let reason): return "The script file could not be read: \(reason)"
        case .empty: return "The script file has no readable text."
        }
    }
}

enum LinkedScriptStore {
    static func makeBookmark(for url: URL) throws -> Data { throw LinkedScriptError.bookmarkInvalid }
    static func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) { throw LinkedScriptError.bookmarkInvalid }
    static func loadPages(from url: URL) throws -> [String] { throw LinkedScriptError.empty }
}
```

Stub tests (each file): `import XCTest` + `@testable import MarkdownScript` + one empty `final class … : XCTestCase { func testPlaceholder() {} }` named `MarkdownScriptParserTests` / `LinkedScriptStoreTests`.

- [ ] **Step 4: Ignore build output**

Append `Textream/.build/` to `/Users/user/Developer/textream/.gitignore` (create if absent).

- [ ] **Step 5: Verify the harness and the Xcode project both build**

Run: `cd /Users/user/Developer/textream/Textream && swift test 2>&1 | tail -5`
Expected: `Executed 2 tests, with 0 failures`.

Run: `cd /Users/user/Developer/textream/Textream && xcodebuild -project Textream.xcodeproj -scheme Textream -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -15`
Expected: no `error:` lines (exit 0). If the new stubs aren't auto-included, stop and report. If a SwiftPM "unhandled files" warning appears, that is acceptable.

- [ ] **Step 6: Commit**

```bash
cd /Users/user/Developer/textream && /usr/bin/git add Textream/Package.swift Textream/MarkdownScriptTests Textream/Textream/MarkdownScriptParser.swift Textream/Textream/LinkedScriptStore.swift .gitignore docs && /usr/bin/git commit -m "chore: scaffold SwiftPM harness and stubs for markdown linked scripts"
```

---

### Task 1: MarkdownScriptParser

**Files:**
- Modify: `Textream/Textream/MarkdownScriptParser.swift` (replace stub body)
- Test: `Textream/MarkdownScriptTests/MarkdownScriptParserTests.swift` (replace placeholder)

**Interfaces:**
- Consumes: nothing.
- Produces: `MarkdownScriptParser.parse(_ source: String, isPlainText: Bool = false) -> [String]`. Pages are trimmed, non-empty, and use `\n` line endings. Returns `[]` if nothing speakable remains.

**Pipeline (apply in this order):**
1. Remove a leading BOM; normalise `\r\n` and `\r` to `\n`.
2. If `isPlainText`: split on lines that are exactly `---` (trimmed), trim each page, drop empties, return. Nothing else.
3. Frontmatter: if line 0 is `---` and a later line is `---` or `...`, drop lines 0…that line. If never closed, do **not** treat as frontmatter.
4. Fenced code: a line starting (after ≤3 spaces) with ``` or `~~~` opens a fence; drop it, the contents and the closing fence line. An unclosed fence drops to end of file.
5. Remove `<!--` … `-->` (may span lines) and `%%` … `%%` (may span lines) using `NSRegularExpression` with `.dotMatchesLineSeparators`.
6. Walk lines, building pages:
   - Page break if line matches `^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$` → flush current page, continue.
   - Heading if matches `^ {0,3}#{1,6}[ \t]+(.*)$` → flush current page, then start the new page with the heading text, with trailing `[ \t]+#+[ \t]*$` closing hashes removed. A `#` with no following space (e.g. `#tag`, `#5`) is **not** a heading.
   - Drop footnote definition lines `^\[\^[^\]]+\]:`.
   - Table: line whose trimmed text starts with `|`. Separator rows (`^\|?[\s:\-|]+\|?$` that contain a `-`) are dropped. Other rows: split on `|`, trim, discard empty cells, join with one space.
   - Strip leading blockquote markers `^\s*(>\s?)+`, then a callout marker `^\[![A-Za-z-]+\][+-]?\s*`.
   - Strip task markers `^\s*[-*+]\s+\[[ xX]\]\s+`, then list markers `^\s*(?:[-*+]|\d+[.)])\s+`.
   - Apply inline stripping (below) to the resulting text.
7. Inline stripping order: `<br>`/`<br/>` to `\n`; images `!\[[^\]]*\]\([^)]*\)` to ``; embeds `!\[\[[^\]]*\]\]` to ``; wikilinks `\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]` to alias if present else target (use `matches` + manual replacement); links `\[([^\]]+)\]\([^)]*\)` to `$1`; footnote refs `\[\^[^\]]+\]` to ``; HTML tags `</?[A-Za-z][^>]*>` to ``; bold `\*\*(.+?)\*\*`, `~~(.+?)~~`, `==(.+?)==`, bold-underscore `(?<![A-Za-z0-9_])__(.+?)__(?![A-Za-z0-9_])` to `$1`; italic `(?<![A-Za-z0-9*])\*(?!\s)(.+?)(?<![\s*])\*(?![A-Za-z0-9*])` and `(?<![A-Za-z0-9_])_(?!\s)(.+?)(?<![\s_])_(?![A-Za-z0-9_])` to `$1`; inline code `` `([^`]+)` `` to `$1`; finally collapse runs of spaces/tabs to one space and trim line ends.
8. Join page lines with `\n`, collapse 3+ consecutive `\n` to `\n\n`, trim, drop empty pages.

- [ ] **Step 1: Write the failing tests**

Replace `Textream/MarkdownScriptTests/MarkdownScriptParserTests.swift` with:

```swift
import XCTest
@testable import MarkdownScript

final class MarkdownScriptParserTests: XCTestCase {
    private func parse(_ s: String) -> [String] { MarkdownScriptParser.parse(s) }

    // MARK: Pages
    func testPlainParagraphIsOnePage() {
        XCTAssertEqual(parse("Hello world."), ["Hello world."])
    }
    func testHorizontalRuleSplitsPages() {
        XCTAssertEqual(parse("One\n\n---\n\nTwo"), ["One", "Two"])
    }
    func testStarAndUnderscoreAndSpacedRulesSplit() {
        XCTAssertEqual(parse("A\n***\nB\n___\nC\n- - -\nD"), ["A", "B", "C", "D"])
    }
    func testHeadingStartsNewPageAndKeepsText() {
        XCTAssertEqual(parse("Intro text\n\n# Next\nBody"), ["Intro text", "Next\nBody"])
    }
    func testLeadingHeadingDoesNotCreateEmptyFirstPage() {
        XCTAssertEqual(parse("# Title\nBody"), ["Title\nBody"])
    }
    func testAllHeadingLevelsSplit() {
        XCTAssertEqual(parse("## Two\ntext\n###### Six\nmore"), ["Two\ntext", "Six\nmore"])
    }
    func testHeadingClosingHashesStripped() {
        XCTAssertEqual(parse("# Title #\nbody"), ["Title\nbody"])
    }
    func testHashNotAHeadingMidLineOrWithoutSpace() {
        XCTAssertEqual(parse("Issue #5 is open"), ["Issue #5 is open"])
        XCTAssertEqual(parse("#tag line"), ["#tag line"])
    }
    func testEmptyPagesDropped() {
        XCTAssertEqual(parse("One\n---\n\n---\nTwo"), ["One", "Two"])
    }
    func testBlankLineRunsCollapsed() {
        XCTAssertEqual(parse("A\n\n\n\nB"), ["A\n\nB"])
    }
    func testOnlyMarkupReturnsEmpty() {
        XCTAssertEqual(parse("---\n```\ncode\n```"), [])
        XCTAssertEqual(parse(""), [])
    }

    // MARK: Frontmatter, code, comments
    func testFrontmatterDropped() {
        XCTAssertEqual(parse("---\ntitle: x\ntags: [a]\n---\nHello"), ["Hello"])
    }
    func testUnclosedFrontmatterIsNotFrontmatter() {
        XCTAssertEqual(parse("---\nHello"), ["Hello"])
    }
    func testFencedCodeDropped() {
        XCTAssertEqual(parse("Before\n\n```swift\nlet x = 1\n```\n\nAfter"), ["Before\n\nAfter"])
        XCTAssertEqual(parse("Before\n\n~~~\ncode\n~~~\n\nAfter"), ["Before\n\nAfter"])
    }
    func testUnclosedFenceDropsToEnd() {
        XCTAssertEqual(parse("Before\n```\ncode"), ["Before"])
    }
    func testHTMLCommentDropped() {
        XCTAssertEqual(parse("A <!-- note --> B"), ["A B"])
        XCTAssertEqual(parse("A\n<!--\nhidden\n-->\nB"), ["A\n\nB"])
    }
    func testObsidianCommentDropped() {
        XCTAssertEqual(parse("A %%hidden%% B"), ["A B"])
    }

    // MARK: Links, images, wikilinks, cues
    func testLinkKeepsText() {
        XCTAssertEqual(parse("See [the docs](https://x.com/a_b) now"), ["See the docs now"])
    }
    func testImageAndEmbedDropped() {
        XCTAssertEqual(parse("Look ![alt](pic.png) here"), ["Look here"])
        XCTAssertEqual(parse("Look ![[pic.png]] here"), ["Look here"])
    }
    func testWikilinks() {
        XCTAssertEqual(parse("[[Page]]"), ["Page"])
        XCTAssertEqual(parse("[[Page|Alias]]"), ["Alias"])
        XCTAssertEqual(parse("[[Page#Heading]]"), ["Page"])
        XCTAssertEqual(parse("[[Page#Heading|Alias]]"), ["Alias"])
    }
    func testCueBracketsPreserved() {
        XCTAssertEqual(parse("Hello. [pause] World [smile]"), ["Hello. [pause] World [smile]"])
    }
    func testCueNextToLinkPreserved() {
        XCTAssertEqual(parse("[pause] see [docs](http://x) [smile]"), ["[pause] see docs [smile]"])
    }
    func testFootnotes() {
        XCTAssertEqual(parse("Fact[^1] here\n\n[^1]: the note"), ["Fact here"])
    }

    // MARK: Inline formatting
    func testEmphasisStripped() {
        XCTAssertEqual(
            parse("**bold** and *italic* and __b__ and _i_ and ~~s~~ and ==h=="),
            ["bold and italic and b and i and s and h"]
        )
    }
    func testSnakeCaseAndMathUntouched() {
        XCTAssertEqual(parse("use my_var_name and 2*3*4"), ["use my_var_name and 2*3*4"])
    }
    func testInlineCodeUnwrapped() {
        XCTAssertEqual(parse("run `ls -la` now"), ["run ls -la now"])
    }
    func testHTMLTagsStripped() {
        XCTAssertEqual(parse("A<br>B <b>bold</b>"), ["A\nB bold"])
    }

    // MARK: Blocks
    func testListMarkersRemoved() {
        XCTAssertEqual(
            parse("- one\n- two\n* three\n+ four\n1. five\n2) six"),
            ["one\ntwo\nthree\nfour\nfive\nsix"]
        )
    }
    func testTaskListMarkersRemoved() {
        XCTAssertEqual(parse("- [ ] todo\n- [x] done"), ["todo\ndone"])
    }
    func testBlockquoteAndCallout() {
        XCTAssertEqual(parse("> quoted\n> [!note] Title\n> body"), ["quoted\nTitle\nbody"])
    }
    func testTableFlattened() {
        XCTAssertEqual(parse("| A | B |\n|---|---|\n| 1 | 2 |"), ["A B\n1 2"])
    }

    // MARK: Encodings and plain text
    func testCRLFAndBOM() {
        XCTAssertEqual(parse("\u{FEFF}One\r\n\r\n---\r\nTwo"), ["One", "Two"])
    }
    func testPlainTextModeDoesNotStripOrSplitOnHeadings() {
        XCTAssertEqual(
            MarkdownScriptParser.parse("# not heading **x**\n---\nTwo", isPlainText: true),
            ["# not heading **x**", "Two"]
        )
    }
    func testPlainTextModeHandlesCRLF() {
        XCTAssertEqual(MarkdownScriptParser.parse("A\r\n---\r\nB", isPlainText: true), ["A", "B"])
    }
}
```

- [ ] **Step 2: Run tests, expect failure**

Run: `cd /Users/user/Developer/textream/Textream && swift test --filter MarkdownScriptParserTests 2>&1 | tail -15`
Expected: many failures (stub returns `[]`).

- [ ] **Step 3: Implement the parser** following the Pipeline above. Structure: `parse` calls small `private static` helpers (`normalise`, `dropFrontmatter`, `dropFencedCode`, `dropComments`, `buildPages`, `stripInline`). Cache compiled `NSRegularExpression`s in `private static let` constants. Use a helper `replace(_ pattern: String, in: String, with template: String, options:)` for the simple `$1` replacements, and an explicit `matches` loop for wikilinks.

- [ ] **Step 4: Run tests, expect all pass**

Run: `cd /Users/user/Developer/textream/Textream && swift test --filter MarkdownScriptParserTests 2>&1 | tail -8`
Expected: `Executed 36 tests, with 0 failures` (count may differ by one or two, but 0 failures). If a test seems wrong rather than the code, stop and report instead of editing the test.

- [ ] **Step 5: Hand back for overseer review.** Do not commit.

---

### Task 2: LinkedScriptStore

**Files:**
- Modify: `Textream/Textream/LinkedScriptStore.swift` (replace stub bodies; keep the error enum exactly as in Task 0)
- Test: `Textream/MarkdownScriptTests/LinkedScriptStoreTests.swift`

**Interfaces:**
- Consumes: `MarkdownScriptParser.parse(_:isPlainText:)` (Task 1; during Wave 1 it may still be a stub, so write tests that only depend on parser behaviour for trivially simple input such as `"Hello"` to `["Hello"]` once Task 1 lands, and run the full suite after both finish).
- Produces:
  - `LinkedScriptStore.makeBookmark(for url: URL) throws -> Data` (uses `.withSecurityScope`; on failure throws `.bookmarkInvalid`)
  - `LinkedScriptStore.resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)` (`.withSecurityScope`, `.withoutUI`; failure throws `.bookmarkInvalid`)
  - `LinkedScriptStore.loadPages(from url: URL) throws -> [String]`: calls `url.startAccessingSecurityScopedResource()` (defer `stop` only if start returned true); reads bytes; decodes UTF-8, falling back to UTF-16 (BOM) then `.isoLatin1`; parses with `isPlainText: url.pathExtension.lowercased() == "txt"`; throws `.unreadable(error.localizedDescription)` on read failure and `.empty` if the parsed pages are empty.

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import MarkdownScript

final class LinkedScriptStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("LinkedScriptStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ data: Data) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    func testLoadPagesParsesMarkdown() throws {
        let url = try write("a.md", Data("# One\nHello\n\n---\n\nTwo".utf8))
        XCTAssertEqual(try LinkedScriptStore.loadPages(from: url), ["One\nHello", "Two"])
    }
    func testLoadPagesTxtIsPlain() throws {
        let url = try write("a.txt", Data("# keep **this**\n---\nTwo".utf8))
        XCTAssertEqual(try LinkedScriptStore.loadPages(from: url), ["# keep **this**", "Two"])
    }
    func testLoadPagesExtensionCaseInsensitive() throws {
        let url = try write("a.TXT", Data("# keep".utf8))
        XCTAssertEqual(try LinkedScriptStore.loadPages(from: url), ["# keep"])
    }
    func testLoadPagesEmptyFileThrowsEmpty() throws {
        let url = try write("e.md", Data())
        XCTAssertThrowsError(try LinkedScriptStore.loadPages(from: url)) {
            guard case LinkedScriptError.empty = $0 else { return XCTFail("expected .empty, got \($0)") }
        }
    }
    func testLoadPagesMarkupOnlyThrowsEmpty() throws {
        let url = try write("m.md", Data("---\n```\ncode\n```".utf8))
        XCTAssertThrowsError(try LinkedScriptStore.loadPages(from: url)) {
            guard case LinkedScriptError.empty = $0 else { return XCTFail("expected .empty, got \($0)") }
        }
    }
    func testLoadPagesMissingFileThrowsUnreadable() {
        let url = dir.appendingPathComponent("nope.md")
        XCTAssertThrowsError(try LinkedScriptStore.loadPages(from: url)) {
            guard case LinkedScriptError.unreadable = $0 else { return XCTFail("expected .unreadable, got \($0)") }
        }
    }
    func testLoadPagesUTF16WithBOM() throws {
        var data = Data([0xFF, 0xFE])
        data.append("Hello".data(using: .utf16LittleEndian)!)
        let url = try write("u16.md", data)
        XCTAssertEqual(try LinkedScriptStore.loadPages(from: url), ["Hello"])
    }
    func testLoadPagesLatin1Fallback() throws {
        let url = try write("l1.md", Data([0x43, 0x61, 0x66, 0xE9])) // "Café" in Latin-1, invalid UTF-8
        XCTAssertEqual(try LinkedScriptStore.loadPages(from: url), ["Café"])
    }
    func testBookmarkRoundTrip() throws {
        let url = try write("b.md", Data("Hello".utf8))
        let data = try LinkedScriptStore.makeBookmark(for: url)
        let resolved = try LinkedScriptStore.resolveBookmark(data)
        XCTAssertEqual(resolved.url.standardizedFileURL.resolvingSymlinksInPath().path,
                       url.standardizedFileURL.resolvingSymlinksInPath().path)
        XCTAssertFalse(resolved.isStale)
    }
    func testResolveGarbageBookmarkThrows() {
        XCTAssertThrowsError(try LinkedScriptStore.resolveBookmark(Data([1, 2, 3]))) {
            guard case LinkedScriptError.bookmarkInvalid = $0 else { return XCTFail("expected .bookmarkInvalid, got \($0)") }
        }
    }
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd /Users/user/Developer/textream/Textream && swift test --filter LinkedScriptStoreTests 2>&1 | tail -15`
Expected: failures (stubs).

- [ ] **Step 3: Implement** the three functions per the Interfaces block. Decode helper: try `String(data:encoding:.utf8)`; if the data starts with `FF FE` or `FE FF`, use `.utf16`; else `.isoLatin1` (never fails). Strip nothing else (the parser removes a BOM).

- [ ] **Step 4: Run, expect pass**

Run: `cd /Users/user/Developer/textream/Textream && swift test --filter LinkedScriptStoreTests 2>&1 | tail -8`
Expected: 0 failures (the tests that need a real parser pass once Task 1 is merged; if Task 1 isn't merged yet, report which tests depend on it and stop).

- [ ] **Step 5: Hand back for overseer review.** Do not commit.

---

### Task 3: Read-only support in HighlightingTextEditor

**Files:**
- Modify: `Textream/Textream/HighlightingTextEditor.swift` (struct properties near the top; `makeNSView` line ~42; `updateNSView` line ~71)

**Interfaces:**
- Consumes: nothing.
- Produces: `HighlightingTextEditor(text:font:highlightRange:caretPosition:editorCaretPosition:isEditable:)` where `isEditable: Bool = true` is the last property with a default (so existing call sites compile unchanged).

- [ ] **Step 1: Read the file** (192 lines) to see the struct's stored properties and `updateNSView`.

- [ ] **Step 2: Add the property** `var isEditable: Bool = true` as the last stored property of `HighlightingTextEditor`.

- [ ] **Step 3: Apply it.** In `makeNSView` replace `textView.isEditable = true` with `textView.isEditable = isEditable`. At the top of `updateNSView` (after the existing `guard … textView` line) add `textView.isEditable = isEditable`. Leave `isSelectable` as is so linked text can still be selected and copied.

- [ ] **Step 4: Verify the app target builds**

Run: `cd /Users/user/Developer/textream/Textream && xcodebuild -project Textream.xcodeproj -scheme Textream -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -15`
Expected: no `error:` lines.

- [ ] **Step 5: Hand back for overseer review.** Do not commit.

---

### Task 4: TextreamService integration

**Files:**
- Modify: `Textream/Textream/TextreamService.swift`

**Interfaces:**
- Consumes: `LinkedScriptStore.makeBookmark/resolveBookmark/loadPages`, `LinkedScriptError` (Task 2).
- Produces (exact names; Tasks 5 and 6 rely on these):
  - `@Published var linkedScriptURL: URL?`
  - `@Published var linkedScriptWarning: String?`
  - `var isScriptLinked: Bool { linkedScriptURL != nil }`
  - `static let scriptExtensions: Set<String> = ["md", "markdown", "txt"]`
  - `func openScriptFile(_ url: URL)` — router: `textream` to `openFileAtURL`, `pptx` to `importPresentation`, `key` to the existing Keynote alert, `scriptExtensions` to `linkScript`, anything else to an "Unsupported file" alert.
  - `func linkScript(_ url: URL)`
  - `@discardableResult func refreshLinkedScript() -> Bool` — returns true if pages were reloaded successfully (or nothing to do).
  - `func unlinkScript()`
  - `func restoreLinkedScript()` — safe to call more than once; no-op if already linked or no bookmark stored.

**Behaviour:**
- `linkScript(url)`: `guard confirmDiscardIfNeeded()`; `loadPages` (on error show an `NSAlert` titled "Failed to link script" with the error text and return); set `pages`, `savedPages = pages`, `currentPageIndex = 0`, `readPages.removeAll()`, `currentFileURL = nil`, `linkedScriptURL = url`, `linkedScriptWarning = nil`; store the bookmark under `UserDefaults` key `linkedScriptBookmark` (ignore bookmark failure but keep the link for the session); `rememberDocumentURL(url)`; `NSDocumentController.shared.noteNewRecentDocumentURL(url)`.
- `refreshLinkedScript()`: if not linked return true. Resolve the bookmark if present (if stale, re-make and store it; if resolving fails fall back to `linkedScriptURL`). `loadPages`; on success: if `newPages != pages`, set `pages = newPages`, `savedPages = newPages`, clamp `currentPageIndex` to `pages.count - 1`; clear the warning; return true. On failure set `linkedScriptWarning` to `"Couldn't re-read \(name): \(error.localizedDescription). Using the last version."`, keep pages untouched, return false.
- `unlinkScript()`: `linkedScriptURL = nil`, `linkedScriptWarning = nil`, remove the bookmark key. Pages stay and become editable; `savedPages` unchanged.
- `restoreLinkedScript()`: guard not already linked and the bookmark exists; resolve; `loadPages`. On any failure remove the bookmark and leave the pages untouched (silent; don't alert on launch). On success set `pages`, `savedPages`, `currentPageIndex = 0`, `linkedScriptURL`, refresh the bookmark if stale.
- `openFile()` panel: add `md`, `markdown`, `txt` via `UTType(filenameExtension:)` with `compactMap` (no force unwrap for the new ones), and replace the `ext` branching with `self?.openScriptFile(url)`.
- `saveToURL`: if `isScriptLinked`, write the snapshot but do **not** set `currentFileURL`, do **not** change `savedPages` and do **not** unlink (the link, not the snapshot, is the source of truth). Still call `rememberDocumentURL(url)` and note the recent document. If not linked, behave exactly as today.
- `saveFile()`: when linked, always go to `saveFileAs()` (because `currentFileURL` is nil it already does).
- The Keynote alert text moves unchanged into the router so behaviour is identical.

- [ ] **Step 1: Read `TextreamService.swift` lines 173–340 again** so edits are made against the current text.

- [ ] **Step 2: Add the state and constants** (near `currentFileURL`, line ~173): the two `@Published` vars, `isScriptLinked`, `scriptExtensions`, and `private static let linkedScriptBookmarkDefaultsKey = "linkedScriptBookmark"`.

- [ ] **Step 3: Implement `openScriptFile`, `linkScript`, `refreshLinkedScript`, `unlinkScript`, `restoreLinkedScript`** in a new `// MARK: - Linked Scripts` section after `openFileAtURL`, per Behaviour above. Use a private helper `private func storeBookmark(for url: URL)` and `private func linkedScriptBookmarkData() -> Data?`.

- [ ] **Step 4: Update `openFile()`** panel types and the completion handler as described.

- [ ] **Step 5: Update `saveToURL`** as described (guard on `isScriptLinked`).

- [ ] **Step 6: Build**

Run: `cd /Users/user/Developer/textream/Textream && xcodebuild -project Textream.xcodeproj -scheme Textream -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -15`
Expected: no `error:` lines.

- [ ] **Step 7: Hand back for overseer review.** Do not commit.

---

### Task 5: ContentView — banner, read-only, disabled controls, drop, Play refresh

**Files:**
- Modify: `Textream/Textream/ContentView.swift`

**Interfaces:**
- Consumes: Task 3 `HighlightingTextEditor(isEditable:)`; Task 4 `service.isScriptLinked`, `service.linkedScriptURL`, `service.linkedScriptWarning`, `service.linkScript(_:)`, `service.refreshLinkedScript()`, `service.unlinkScript()`, `service.restoreLinkedScript()`, `TextreamService.scriptExtensions`.
- Produces: nothing for other tasks.

**Behaviour:**
- Editor (`mainContent`, line ~279): pass `isEditable: !service.isScriptLinked`.
- Banner: new `linkedScriptBanner` view, shown at the top of `mainContent`'s `VStack` (next to `languageSuggestionBanner`) when `service.isScriptLinked`. Same visual style as `languageSuggestionBanner` (copy its padding/material/overlay). Icon `link`. Title `"Linked to \(service.linkedScriptURL!.lastPathComponent)"` (use optional binding, not force unwrap). Subtitle `"Re-read from the file each time you press Play."`, or the warning text in `.orange` when `service.linkedScriptWarning != nil`. An **Unlink** button (`.borderedProminent`, `.controlSize(.small)`) calling `service.unlinkScript()`.
- Disable while linked: toolbar "Page" button and the sidebar "Add Page" button (`.disabled(service.isScriptLinked)`, with the usual `.opacity`); the sidebar "Delete Page" context-menu item (`if service.pages.count > 1 && !service.isScriptLinked`); the dictation mic button (add `|| service.isScriptLinked` to its `.disabled` and `.opacity` conditions).
- Toolbar title (line ~546): show `service.linkedScriptURL?.deletingPathExtension().lastPathComponent` when linked, else the existing expression. The orange unsaved dot only when not linked.
- `run()` (line ~753): call `service.refreshLinkedScript()` as the first statement after the `hasAnyContent` guard, then re-check `hasAnyContent` (the refresh can change pages).
- Drop target (line ~401): replace the `.key`/`.pptx`-only logic. `.key` keeps its existing alert; `.pptx` keeps `handlePresentationDrop`; extensions in `TextreamService.scriptExtensions` call a new `handleScriptDrop(url:)` on the main queue, which stops recording if needed and calls `service.linkScript(url)`; anything else shows `"Unsupported file. Drop a PowerPoint (.pptx), Markdown (.md) or text (.txt) file."`. Update the overlay copy from `"Drop PowerPoint (.pptx) file"` to `"Drop a script (.md, .txt) or PowerPoint (.pptx)"`, and keep the Keynote/Google Slides hint.
- `onAppear` (line ~639): call `service.restoreLinkedScript()` **before** the default-text check, and guard the default-text insertion with `!service.isScriptLinked`.

- [ ] **Step 1: Read `ContentView.swift` lines 271–430, 531–660 and 753–803** to edit against the current text.
- [ ] **Step 2: Implement** the behaviours above. Reuse existing styles; add no new files.
- [ ] **Step 3: Build**

Run: `cd /Users/user/Developer/textream/Textream && xcodebuild -project Textream.xcodeproj -scheme Textream -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -15`
Expected: no `error:` lines.
- [ ] **Step 4: Hand back for overseer review.** Do not commit.

---

### Task 6: App-level routing and Info.plist

**Files:**
- Modify: `Textream/Textream/TextreamApp.swift` (lines ~125–144 and ~152–160)
- Modify: `Textream/Info.plist`

**Interfaces:**
- Consumes: Task 4 `TextreamService.shared.openScriptFile(_:)` and `TextreamService.scriptExtensions`.
- Produces: nothing.

**Behaviour:**
- `application(_:open:)`: for URLs whose lowercased extension is `textream`, `pptx`, or in `scriptExtensions`, call `openScriptFile(url)` and show the main window exactly as the existing `.textream` branch does. Everything else keeps the existing `handleURL` branch.
- `onOpenURL`: same routing (`textream`/`pptx`/script extensions to `openScriptFile`, else `handleURL`). Use the lowercased extension.
- `Info.plist`: add three more entries to `CFBundleDocumentTypes` (keep the existing Textream Document entry untouched): "Markdown Document" (`LSItemContentTypes`: `net.daringfireball.markdown`), "Plain Text Document" (`public.plain-text`), each with `CFBundleTypeRole` `Viewer` and `LSHandlerRank` `Alternate`, so Textream appears under Open With but never steals the default app for `.md`/`.txt`.
- Menu item text "Open File or Presentation…" stays as is.

- [ ] **Step 1: Read both files' relevant regions.**
- [ ] **Step 2: Implement** the routing and plist entries.
- [ ] **Step 3: Validate the plist**

Run: `plutil -lint /Users/user/Developer/textream/Textream/Info.plist`
Expected: `OK`.
- [ ] **Step 4: Build**

Run: `cd /Users/user/Developer/textream/Textream && xcodebuild -project Textream.xcodeproj -scheme Textream -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -15`
Expected: no `error:` lines.
- [ ] **Step 5: Hand back for overseer review.** Do not commit.

---

### Task 7: Integration, review and manual checklist (overseer)

- [ ] **Step 1:** `swift test` in `Textream/` — all parser and store tests pass.
- [ ] **Step 2:** Clean `xcodebuild … build` of the `Textream` scheme, and a build of the `TextreamiOS` scheme to confirm iOS is untouched (`-destination 'generic/platform=iOS Simulator'`, `CODE_SIGNING_ALLOWED=NO`).
- [ ] **Step 3:** Whole-branch code review (`superpowers:requesting-code-review`) against this plan's Global Constraints and Review Focus.
- [ ] **Step 4:** Launch the built app and walk this checklist with a real Obsidian note, reporting each result faithfully:
  1. Open (Cmd-O) a `.md` file → banner shows, text is stripped, multiple pages in sidebar, editor read-only.
  2. Edit the `.md` in another app, press Play → new text is shown.
  3. Rename the `.md`, press Play → warning banner, prompter still plays the last text.
  4. Cmd-S → Save panel proposes a `.textream` name; original `.md` unchanged on disk.
  5. Unlink → editor becomes editable, pages retained.
  6. Link again, quit, relaunch → link restored.
  7. Drag a `.md` onto the window → links; drag a `.docx` → unsupported alert.
  8. `[pause]` cues still appear italic and are auto-skipped while reading.
- [ ] **Step 5:** Report to the user; do not push or open a PR without being asked.
