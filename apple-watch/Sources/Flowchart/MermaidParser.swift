import Foundation

public class MermaidParser {

    private static let patternEdgeDash = try? NSRegularExpression(
        pattern: "([A-Za-z0-9_]+(?:\\s*&\\s*[A-Za-z0-9_]+)*)\\s*(?:\\[[^\\]]*\\]|\\{[^\\}]*\\}|\\([^\\)]*\\))?\\s+--\\s*(.+?)\\s*-->\\s*([A-Za-z0-9_]+(?:\\s*&\\s*[A-Za-z0-9_]+)*)"
    )

    private static let patternEdgePipe = try? NSRegularExpression(
        pattern: "([A-Za-z0-9_]+(?:\\s*&\\s*[A-Za-z0-9_]+)*)\\s*(?:\\[[^\\]]*\\]|\\{[^\\}]*\\}|\\([^\\)]*\\))?\\s*(?:-->|-\\.->|==>|---)\\s*(?:\\|(.*?)\\|)?\\s*([A-Za-z0-9_]+(?:\\s*&\\s*[A-Za-z0-9_]+)*)"
    )

    private static let patternDecisionNode = try? NSRegularExpression(
        pattern: "([A-Za-z0-9_]+)\\s*\\{([^\\}]+)\\}"
    )

    private static let patternProcessNode = try? NSRegularExpression(
        pattern: "([A-Za-z0-9_]+)\\s*\\[([^\\]]+)\\]"
    )

    private static let patternRoundedNode = try? NSRegularExpression(
        pattern: "([A-Za-z0-9_]+)\\s*\\(([^\\)]+)\\)"
    )

    public static func parse(_ mermaidCode: String) -> MermaidModel.Graph {
        let graph = MermaidModel.Graph()
        let trimmedCode = mermaidCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCode.isEmpty {
            return graph
        }

        let lines = trimmedCode.components(separatedBy: .newlines)
        for line in lines {
            let lineTrimmed = line.trimmingCharacters(in: .whitespaces)
            if lineTrimmed.isEmpty || lineTrimmed.starts(with: "graph") || lineTrimmed.starts(with: "flowchart") || lineTrimmed.starts(with: "%%") {
                continue
            }

            // Extract Node definitions embedded in line
            extractNodes(from: lineTrimmed, into: graph)

            // Extract Edges
            var matchedDash = false
            if let dashRegex = patternEdgeDash {
                let matches = dashRegex.matches(in: lineTrimmed, range: NSRange(lineTrimmed.startIndex..., in: lineTrimmed))
                if !matches.isEmpty {
                    matchedDash = true
                    for match in matches {
                        if let fromRange = Range(match.range(at: 1), in: lineTrimmed),
                           let labelRange = Range(match.range(at: 2), in: lineTrimmed),
                           let toRange = Range(match.range(at: 3), in: lineTrimmed) {
                            let from = String(lineTrimmed[fromRange])
                            let label = String(lineTrimmed[labelRange])
                            let to = String(lineTrimmed[toRange])
                            addEdges(into: graph, fromGroup: from, label: label, toGroup: to)
                        }
                    }
                }
            }

            if !matchedDash, let pipeRegex = patternEdgePipe {
                let matches = pipeRegex.matches(in: lineTrimmed, range: NSRange(lineTrimmed.startIndex..., in: lineTrimmed))
                for match in matches {
                    if let fromRange = Range(match.range(at: 1), in: lineTrimmed),
                       let toRange = Range(match.range(at: 3), in: lineTrimmed) {
                        let from = String(lineTrimmed[fromRange])
                        let to = String(lineTrimmed[toRange])
                        var label: String? = nil
                        if match.range(at: 2).location != NSNotFound, let lRange = Range(match.range(at: 2), in: lineTrimmed) {
                            label = String(lineTrimmed[lRange])
                        }
                        addEdges(into: graph, fromGroup: from, label: label, toGroup: to)
                    }
                }
            }
        }

        normalizeConvergenceEdges(graph)
        return graph
    }

    private static func extractNodes(from line: String, into graph: MermaidModel.Graph) {
        // 1. Decisions { ... }
        if let regex = patternDecisionNode {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: line),
                   let textRange = Range(match.range(at: 2), in: line) {
                    let id = String(line[idRange]).trimmingCharacters(in: .whitespaces)
                    let text = cleanLabel(String(line[textRange]))
                    if let existing = graph.findNode(id: id) {
                        existing.text = text
                        existing.isDecision = true
                    } else {
                        graph.nodes.append(MermaidModel.Node(id: id, text: text, isDecision: true))
                    }
                }
            }
        }

        // 2. Standard rectangular process [ ... ]
        if let regex = patternProcessNode {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: line),
                   let textRange = Range(match.range(at: 2), in: line) {
                    let id = String(line[idRange]).trimmingCharacters(in: .whitespaces)
                    let text = cleanLabel(String(line[textRange]))
                    if let existing = graph.findNode(id: id) {
                        if !existing.isDecision { existing.text = text }
                    } else {
                        graph.nodes.append(MermaidModel.Node(id: id, text: text, isDecision: false))
                    }
                }
            }
        }

        // 3. Rounded process ( ... )
        if let regex = patternRoundedNode {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let idRange = Range(match.range(at: 1), in: line),
                   let textRange = Range(match.range(at: 2), in: line) {
                    let id = String(line[idRange]).trimmingCharacters(in: .whitespaces)
                    let text = cleanLabel(String(line[textRange]))
                    if let existing = graph.findNode(id: id) {
                        if !existing.isDecision { existing.text = text }
                    } else {
                        graph.nodes.append(MermaidModel.Node(id: id, text: text, isDecision: false))
                    }
                }
            }
        }
    }

    private static func addEdges(into graph: MermaidModel.Graph, fromGroup: String, label: String?, toGroup: String) {
        let cleanedLabel = label.map { cleanLabel($0) }

        let fromIds = fromGroup.components(separatedBy: "&")
        let toIds = toGroup.components(separatedBy: "&")

        for fromRaw in fromIds {
            let from = fromRaw.trimmingCharacters(in: .whitespaces)
            if from.isEmpty { continue }
            if graph.findNode(id: from) == nil {
                graph.nodes.append(MermaidModel.Node(id: from, text: from, isDecision: false))
            }

            for toRaw in toIds {
                let to = toRaw.trimmingCharacters(in: .whitespaces)
                if to.isEmpty { continue }
                if graph.findNode(id: to) == nil {
                    graph.nodes.append(MermaidModel.Node(id: to, text: to, isDecision: false))
                }
                graph.edges.append(MermaidModel.Edge(fromId: from, toId: to, label: cleanedLabel))
            }
        }
    }

    private static func normalizeConvergenceEdges(_ graph: MermaidModel.Graph) {
        // Multi-edge normalization ensuring rule discipline
        var pairs: [String: [MermaidModel.Edge]] = [:]
        for edge in graph.edges {
            let key = "\(edge.fromId)->\(edge.toId)"
            pairs[key, default: []].append(edge)
        }

        for (key, edgeList) in pairs where edgeList.count > 1 {
            let parts = key.components(separatedBy: "->")
            guard parts.count == 2 else { continue }
            let fromId = parts[0]
            let toId = parts[1]

            // Remove existing duplicate direct edges
            graph.edges.removeAll { $0.fromId == fromId && $0.toId == toId }

            for (idx, e) in edgeList.enumerated() {
                let syntheticId = "\(fromId)_to_\(toId)_\(idx + 1)"
                let condText = e.label ?? "Option \(idx + 1)"
                graph.nodes.append(MermaidModel.Node(id: syntheticId, text: condText, isDecision: false))
                graph.edges.append(MermaidModel.Edge(fromId: fromId, toId: syntheticId, label: nil))
                graph.edges.append(MermaidModel.Edge(fromId: syntheticId, toId: toId, label: nil))
            }
        }
    }

    private static func cleanLabel(_ label: String) -> String {
        var result = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.starts(with: "\"") && result.hasSuffix("\"") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
        }
        return result.replacingOccurrences(of: "<br/>", with: " ")
                     .replacingOccurrences(of: "<br>", with: " ")
    }
}
