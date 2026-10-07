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
        XCTAssertEqual(parse("## Two\ntext\n###### Six\nmore"), ["Two\ntext\nSix\nmore"])
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
    func testLeadingRuleThenProseIsNotFrontmatter() {
        XCTAssertEqual(parse("---\nPage one\n---\nPage two"), ["Page one", "Page two"])
    }
    func testEmptyFrontmatterDropped() {
        XCTAssertEqual(parse("---\n---\nHello"), ["Hello"])
    }
    func testFrontmatterWithListAndComment() {
        XCTAssertEqual(parse("---\n# note\ntags:\n  - a\n  - b\ntitle: Hi\n---\nBody"), ["Body"])
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

    func testHighlightRuleIgnoresProseEquals() {
        XCTAssertEqual(parse("x == y and z == w"), ["x == y and z == w"])
        XCTAssertEqual(parse("==h=="), ["h"])
    }
    func testLongNumberIsNotListMarker() {
        XCTAssertEqual(parse("1984. A novel"), ["1984. A novel"])
    }
    func testLevelThreeHeadingDoesNotSplit() {
        XCTAssertEqual(parse("## Sec\nintro\n### Sub\nmore"), ["Sec\nintro\nSub\nmore"])
    }
    func testHeadingOnlyStubMergesIntoNextPage() {
        XCTAssertEqual(parse("# Title\n## Section\nbody"), ["Title\nSection\nbody"])
    }
    func testStubBeforeRuleMergesIntoNextPage() {
        XCTAssertEqual(parse("## A\n---\nbody"), ["A\nbody"])
    }
    func testTrailingLoneHeadingIsKept() {
        XCTAssertEqual(parse("# Only"), ["Only"])
        XCTAssertEqual(parse("Intro\n## Last"), ["Intro", "Last"])
    }
    func testRealWorldShape() {
        XCTAssertEqual(
            parse("# Doc\n\n---\n\n## 1. Setup\n\n### Gear\nTent and stove.\n\n### Food\nRice.\n\n---\n\n## 2. Plan\nGo north."),
            ["Doc\n1. Setup\nGear\nTent and stove.\n\nFood\nRice.", "2. Plan\nGo north."])
    }
}
