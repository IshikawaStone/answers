import Foundation
import SwiftUI

public struct ExamPaper: Identifiable, Codable, Hashable {
    public var id: String
    public var title: String
    public var date: String
    public var totalMarks: Int
    public var generationMode: String
    public var promptSetUsed: String?
    public var questions: [ExamQuestion]
    
    public var cachedQuestionCount: Int
    public var cachedAnsweredCount: Int

    public init(
        id: String = UUID().uuidString,
        title: String = "MBBS Exam Paper",
        date: String = "",
        totalMarks: Int = 100,
        generationMode: String = "HONOURS",
        promptSetUsed: String? = nil,
        questions: [ExamQuestion] = [],
        cachedQuestionCount: Int = 0,
        cachedAnsweredCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.totalMarks = totalMarks
        self.generationMode = generationMode
        self.promptSetUsed = promptSetUsed
        self.questions = questions
        self.cachedQuestionCount = cachedQuestionCount
        self.cachedAnsweredCount = cachedAnsweredCount
    }

    public var isStandardMode: Bool {
        generationMode.uppercased() == "STANDARD"
    }

    public var questionCount: Int {
        if !questions.isEmpty { return questions.count }
        return cachedQuestionCount
    }

    public var answeredCount: Int {
        if !questions.isEmpty {
            return questions.filter { $0.isAnswered }.count
        }
        return cachedAnsweredCount
    }

    public var isFullyAnswered: Bool {
        if !questions.isEmpty {
            return questions.allSatisfy { $0.isAnswered }
        }
        return cachedQuestionCount > 0 && cachedAnsweredCount >= cachedQuestionCount
    }

    public var promptSetDisplayTag: String {
        guard let pSet = promptSetUsed, !pSet.trimmingCharacters(in: .whitespaces).isEmpty else {
            return generationMode == "STANDARD" ? "Fast Standard" : "Academic"
        }
        switch pSet {
        case "MODULAR_PIPELINE": return "Modular Pipeline"
        case "SUBHEADINGS": return "Subheadings"
        case "NO_BOUNDS_ON_FLOWCHARTS": return "No Bounds Flowcharts"
        case "SHORT_BULLETS_WITH_FLOWCHARTS_SHORTENED": return "Bullets Shortened"
        case "SHORT_BULLETS_WITH_FLOWCHARTS": return "Bullets + Mermaid"
        case "NEW_PROMPTS": return "Academic"
        case "OLD_PROMPTS_DEEP": return "Triple-Lock"
        case "OLD_PROMPTS_STD": return "Fast Standard"
        default: return pSet
        }
    }

    public var promptSetColor: Color {
        let tag = promptSetDisplayTag
        if tag.contains("Bullets") || tag.contains("Mermaid") || tag.contains("Modular") {
            return Color(red: 0.0, green: 0.9, blue: 1.0) // Bright Cyan
        } else if tag.contains("Academic") || tag.contains("Subheadings") {
            return Color(red: 1.0, green: 0.83, blue: 0.31) // Gold
        } else if tag.contains("Triple") {
            return Color(red: 1.0, green: 0.54, blue: 0.5) // Light Red/Coral
        } else {
            return Color(red: 0.5, green: 0.78, blue: 0.52) // Light Green
        }
    }

    public var subjectiveQuestions: [ExamQuestion] {
        questions.filter { !$0.isMcq }
    }

    public var mcqQuestions: [ExamQuestion] {
        questions.filter { $0.isMcq }
    }
}

public struct ExamQuestion: Identifiable, Codable, Hashable {
    public var id: String
    public var number: String
    public var text: String
    public var marks: Int
    public var isMcq: Bool
    public var mcqOptions: [String]
    public var correctOption: String
    public var honoursAnswer: String
    public var status: String

    public init(
        id: String = UUID().uuidString,
        number: String = "Q1",
        text: String = "",
        marks: Int = 10,
        isMcq: Bool = false,
        mcqOptions: [String] = [],
        correctOption: String = "",
        honoursAnswer: String = "",
        status: String = "READY"
    ) {
        self.id = id
        self.number = number
        self.text = text
        self.marks = marks
        self.isMcq = isMcq
        self.mcqOptions = mcqOptions
        self.correctOption = correctOption
        self.honoursAnswer = honoursAnswer
        self.status = status
    }

    public var isAnswered: Bool {
        if status.uppercased() == "FAILED" || status.uppercased() == "INTERRUPTED" {
            return false
        }
        if status.uppercased() == "COMPLETED" {
            return true
        }
        return !honoursAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !honoursAnswer.starts(with: "# CLINICAL REVISION OUTLINE")
    }

    public var marksBadgeText: String {
        return "\(marks)M"
    }

    public var marksBadgeColor: Color {
        if marks >= 10 {
            return Color(red: 0.98, green: 0.62, blue: 0.04) // Amber/Gold
        } else if marks >= 5 {
            return Color(red: 0.22, green: 0.74, blue: 0.97) // Cyan
        } else {
            return Color(red: 0.06, green: 0.73, blue: 0.51) // Emerald
        }
    }
}
