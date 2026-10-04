import SwiftUI

public struct MermaidCanvasView: View {
    public let graph: MermaidModel.Graph
    @State private var measuredHeight: CGFloat = 200

    public init(graph: MermaidModel.Graph) {
        self.graph = graph
    }

    public init(code: String) {
        self.graph = MermaidParser.parse(code)
    }

    public var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let layout = computeLayout(width: width)
            
            Canvas { context, size in
                renderCanvas(context: context, layout: layout)
            }
            .frame(width: width, height: max(layout.totalHeight, 100))
            .onAppear {
                self.measuredHeight = layout.totalHeight
            }
        }
        .frame(height: measuredHeight)
    }

    // MARK: - Layout Computation

    private struct LayoutResult {
        var blocks: [MermaidModel.RenderBlock] = []
        var threadlines: [MermaidModel.Threadline] = []
        var mergeThreadlines: [MermaidModel.MergeThreadline] = []
        var linearConnectors: [(CGPoint, CGPoint, Color)] = []
        var totalHeight: CGFloat = 0
    }

    private func computeLayout(width: CGFloat) -> LayoutResult {
        var result = LayoutResult()
        guard !graph.nodes.isEmpty else { return result }

        let cardMarginLeft: CGFloat = 28
        let cardMarginRight: CGFloat = 16
        let cardWidth = max(width - cardMarginLeft - cardMarginRight, 80)
        let blockSpacing: CGFloat = 26
        let badgeHeight: CGFloat = 18

        var currentY: CGFloat = 14
        var nodeYMap: [String: CGFloat] = [:]
        var nodeBottomMap: [String: CGFloat] = [:]

        // 1. Position Blocks Vertically
        for node in graph.nodes {
            let incoming = graph.getIncomingEdges(nodeId: node.id)
            let branchLabel = incoming.first?.label

            var block = MermaidModel.RenderBlock(
                nodeId: node.id,
                nodeText: node.text,
                isDecision: node.isDecision,
                branchLabel: branchLabel
            )

            // Calculate card height based on text length
            let approxLines = max(1, CGFloat(ceil(Double(node.text.count) / Double(max(15, Int(cardWidth / 7))))))
            let estimatedTextHeight = approxLines * 16
            let cardHeight = max(estimatedTextHeight + 18, 42)

            if let label = branchLabel, !label.isEmpty {
                block.badgeRect = CGRect(x: cardMarginLeft + 4, y: currentY, width: min(cardWidth - 8, CGFloat(label.count * 7 + 16)), height: badgeHeight)
                currentY += badgeHeight + 4
            }

            block.rect = CGRect(x: cardMarginLeft, y: currentY, width: cardWidth, height: cardHeight)
            block.textRect = CGRect(x: cardMarginLeft + 8, y: currentY + 7, width: cardWidth - 16, height: cardHeight - 14)
            block.borderColor = node.isDecision ? Color(red: 1.0, green: 0.83, blue: 0.31) : Color(red: 0.22, green: 0.74, blue: 0.97)

            nodeYMap[node.id] = block.rect.midY
            nodeBottomMap[node.id] = block.rect.maxY

            result.blocks.append(block)
            currentY += cardHeight + blockSpacing
        }

        result.totalHeight = currentY + 10

        // 2. Compute Left Threadlines for Branching & Right Rails for Merges
        let leftThreadX: CGFloat = 14
        let rightRailX: CGFloat = width - 8

        for node in graph.nodes {
            let outgoing = graph.getOutgoingEdges(nodeId: node.id)
            guard let fromBottom = nodeBottomMap[node.id], let fromMidY = nodeYMap[node.id] else { continue }

            if outgoing.count == 1, let target = outgoing.first, let targetTop = result.blocks.first(where: { $0.nodeId == target.toId })?.rect.minY {
                // Direct single downward connector
                let midX = cardMarginLeft + cardWidth / 2
                result.linearConnectors.append((CGPoint(x: midX, y: fromBottom), CGPoint(x: midX, y: targetTop), Color(red: 0.22, green: 0.74, blue: 0.97)))
            } else if outgoing.count > 1 {
                // Multi-branch: Left Threadline
                var targetYs: [CGFloat] = []
                for edge in outgoing {
                    if let targetMidY = nodeYMap[edge.toId] {
                        targetYs.append(targetMidY)
                    }
                }

                if let minY = targetYs.min(), let maxY = targetYs.max() {
                    let startY = min(fromMidY + 12, minY)
                    var threadline = MermaidModel.Threadline(
                        x: leftThreadX,
                        startY: startY,
                        endY: maxY,
                        color: Color(red: 0.22, green: 0.74, blue: 0.97)
                    )

                    for edge in outgoing {
                        if let targetMidY = nodeYMap[edge.toId] {
                            threadline.hooks.append(MermaidModel.BranchHook(
                                y: targetMidY,
                                targetX: cardMarginLeft,
                                isLast: targetMidY == maxY,
                                color: Color(red: 0.22, green: 0.74, blue: 0.97)
                            ))
                        }
                    }
                    result.threadlines.append(threadline)
                }
            }
        }

        // 3. Compute Right Rails for Converging Nodes
        for node in graph.nodes {
            let incoming = graph.getIncomingEdges(nodeId: node.id)
            if incoming.count > 1, let targetMidY = nodeYMap[node.id], let targetCard = result.blocks.first(where: { $0.nodeId == node.id }) {
                var sourceYs: [CGFloat] = []
                for edge in incoming {
                    if let sY = nodeYMap[edge.fromId] {
                        sourceYs.append(sY)
                    }
                }
                if let minY = sourceYs.min() {
                    var merge = MermaidModel.MergeThreadline(
                        x: rightRailX,
                        startY: minY,
                        endY: targetMidY,
                        color: Color(red: 0.96, green: 0.62, blue: 0.04), // Amber collector
                        entryY: targetMidY,
                        entryTargetX: targetCard.rect.maxX
                    )
                    for edge in incoming {
                        if let sY = nodeYMap[edge.fromId], let sCard = result.blocks.first(where: { $0.nodeId == edge.fromId }) {
                            merge.prongs.append(MermaidModel.MergeProng(
                                startX: sCard.rect.maxX,
                                y: sY,
                                color: Color(red: 0.96, green: 0.62, blue: 0.04)
                            ))
                        }
                    }
                    result.mergeThreadlines.append(merge)
                }
            }
        }

        return result
    }

    // MARK: - Canvas Rendering

    private func renderCanvas(context: GraphicsContext, layout: LayoutResult) {
        // 1. Draw Direct Linear Connectors
        for connector in layout.linearConnectors {
            var path = Path()
            path.move(to: connector.0)
            path.addLine(to: connector.1)
            context.stroke(path, with: .color(connector.2), lineWidth: 2)
            drawArrowHead(context: context, at: connector.1, direction: .down, color: connector.2)
        }

        // 2. Draw Left Threadlines & Branch Hooks
        for line in layout.threadlines {
            var path = Path()
            path.move(to: CGPoint(x: line.x, y: line.startY))
            path.addLine(to: CGPoint(x: line.x, y: line.endY))
            context.stroke(path, with: .color(line.color), lineWidth: 2)

            for hook in line.hooks {
                var hookPath = Path()
                hookPath.move(to: CGPoint(x: line.x, y: hook.y))
                hookPath.addLine(to: CGPoint(x: hook.targetX, y: hook.y))
                context.stroke(hookPath, with: .color(hook.color), lineWidth: 2)
                drawArrowHead(context: context, at: CGPoint(x: hook.targetX, y: hook.y), direction: .right, color: hook.color)
            }
        }

        // 3. Draw Right-Rail Convergence Collectors
        for merge in layout.mergeThreadlines {
            // Prongs from source cards into right rail
            for prong in merge.prongs {
                var prongPath = Path()
                prongPath.move(to: CGPoint(x: prong.startX, y: prong.y))
                prongPath.addLine(to: CGPoint(x: merge.x, y: prong.y))
                context.stroke(prongPath, with: .color(prong.color), lineWidth: 2)
            }

            // Continuous Right Rail vertical line
            var railPath = Path()
            railPath.move(to: CGPoint(x: merge.x, y: merge.startY))
            railPath.addLine(to: CGPoint(x: merge.x, y: merge.endY))
            context.stroke(railPath, with: .color(merge.color), lineWidth: 2)

            // Entry prong feeding back into target node card
            var entryPath = Path()
            entryPath.move(to: CGPoint(x: merge.x, y: merge.entryY))
            entryPath.addLine(to: CGPoint(x: merge.entryTargetX, y: merge.entryY))
            context.stroke(entryPath, with: .color(merge.color), lineWidth: 2)
            drawArrowHead(context: context, at: CGPoint(x: merge.entryTargetX, y: merge.entryY), direction: .left, color: merge.color)
        }

        // 4. Draw Cards & Condition Badges
        for block in layout.blocks {
            // Condition Badge [IF: ...]
            if let badgeRect = block.badgeRect, let label = block.branchLabel {
                let badgePath = RoundedRectangle(cornerRadius: 4).path(in: badgeRect)
                context.fill(badgePath, with: .color(Color(red: 0.1, green: 0.1, blue: 0.12)))
                context.stroke(badgePath, with: .color(Color(red: 0.96, green: 0.62, blue: 0.04)), lineWidth: 1)

                let badgeText = Text("[IF: \(label)]")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.96, green: 0.62, blue: 0.04))
                context.draw(context.resolve(badgeText), in: badgeRect.insetBy(dx: 4, dy: 2))
            }

            // Node Card Body
            let cardPath = RoundedRectangle(cornerRadius: 6).path(in: block.rect)
            context.fill(cardPath, with: .color(Color(red: 0.08, green: 0.08, blue: 0.09)))
            context.stroke(cardPath, with: .color(block.borderColor), lineWidth: 1.5)

            // Node Text
            let nodeText = Text(block.nodeText)
                .font(.system(size: 11, weight: block.isDecision ? .semibold : .regular))
                .foregroundColor(.white)
            context.draw(context.resolve(nodeText), in: block.textRect)
        }
    }

    private enum ArrowDirection { case down, right, left }

    private func drawArrowHead(context: GraphicsContext, at point: CGPoint, direction: ArrowDirection, color: Color) {
        var path = Path()
        let size: CGFloat = 4
        switch direction {
        case .down:
            path.move(to: CGPoint(x: point.x - size, y: point.y - size))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x + size, y: point.y - size))
        case .right:
            path.move(to: CGPoint(x: point.x - size, y: point.y - size))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x - size, y: point.y + size))
        case .left:
            path.move(to: CGPoint(x: point.x + size, y: point.y - size))
            path.addLine(to: point)
            path.addLine(to: CGPoint(x: point.x + size, y: point.y + size))
        }
        context.stroke(path, with: .color(color), lineWidth: 2)
    }
}
