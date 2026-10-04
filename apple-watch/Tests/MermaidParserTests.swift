import XCTest
@testable import AnswersWatchCore

final class MermaidParserTests: XCTestCase {

    func testParseSimpleFlowchart() {
        let code = """
        graph TD
          A[Patient with DKA] --> B{Capillary Glucose}
          B -- High --> C[Check Ketones]
          B -- Normal --> D[Alternative Dx]
        """

        let graph = MermaidParser.parse(code)
        XCTAssertEqual(graph.nodes.count, 4)
        XCTAssertEqual(graph.edges.count, 3)

        let nodeA = graph.findNode(id: "A")
        XCTAssertNotNil(nodeA)
        XCTAssertEqual(nodeA?.text, "Patient with DKA")
        XCTAssertFalse(nodeA?.isDecision ?? true)

        let nodeB = graph.findNode(id: "B")
        XCTAssertNotNil(nodeB)
        XCTAssertEqual(nodeB?.text, "Capillary Glucose")
        XCTAssertTrue(nodeB?.isDecision ?? false)
    }

    func testConvergenceNormalization() {
        let code = """
        graph TD
          A[Decision] -- Option 1 --> B[Target]
          A -- Option 2 --> B
        """

        let graph = MermaidParser.parse(code)
        // Multi-edge A->B should be split into distinct synthetic nodes feeding target B
        XCTAssertTrue(graph.nodes.count >= 4)
    }
}
