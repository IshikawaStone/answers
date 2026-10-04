import Foundation
import SwiftUI

public struct MermaidModel {

    public class Node: Identifiable, Hashable {
        public var id: String
        public var text: String
        public var isDecision: Bool // true if {...} diamond

        public init(id: String, text: String, isDecision: Bool) {
            self.id = id
            self.text = text
            self.isDecision = isDecision
        }

        public static func == (lhs: Node, rhs: Node) -> Bool {
            lhs.id == rhs.id
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    public struct Edge: Hashable {
        public var fromId: String
        public var toId: String
        public var label: String?

        public init(fromId: String, toId: String, label: String? = nil) {
            self.fromId = fromId
            self.toId = toId
            self.label = label
        }
    }

    public class Graph {
        public var nodes: [Node] = []
        public var edges: [Edge] = []

        public init() {}

        public func findNode(id: String) -> Node? {
            nodes.first { $0.id == id }
        }

        public func getOutgoingEdges(nodeId: String) -> [Edge] {
            edges.filter { $0.fromId == nodeId }
        }

        public func getIncomingEdges(nodeId: String) -> [Edge] {
            edges.filter { $0.toId == nodeId }
        }
    }

    // Layout models for threadlines and merge rails
    public struct Threadline {
        public var x: CGFloat
        public var startY: CGFloat
        public var endY: CGFloat
        public var color: Color
        public var hooks: [BranchHook] = []
    }

    public struct BranchHook {
        public var y: CGFloat
        public var targetX: CGFloat
        public var isLast: Bool
        public var color: Color
    }

    public struct MergeThreadline {
        public var x: CGFloat
        public var startY: CGFloat
        public var endY: CGFloat
        public var color: Color
        public var prongs: [MergeProng] = []
        public var entryY: CGFloat
        public var entryTargetX: CGFloat
    }

    public struct MergeProng {
        public var startX: CGFloat
        public var y: CGFloat
        public var color: Color
    }

    public struct RenderBlock: Identifiable {
        public var id: String { nodeId }
        public var nodeId: String
        public var nodeText: String
        public var isDecision: Bool
        public var branchLabel: String?
        public var rect: CGRect = .zero
        public var textRect: CGRect = .zero
        public var badgeRect: CGRect?
        public var borderColor: Color = Color(red: 0.22, green: 0.74, blue: 0.97)
    }
}
