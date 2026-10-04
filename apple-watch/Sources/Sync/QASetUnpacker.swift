import Foundation
import zlib

public enum QASetUnpackerError: LocalizedError {
    case invalidMagicHeader
    case decompressionFailed(Int32)
    case invalidJavaStreamHeader
    case unexpectedToken(UInt8, Int)
    case parsingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMagicHeader: return "Invalid .qaset magic header"
        case .decompressionFailed(let code): return "GZIP decompression failed (code \(code))"
        case .invalidJavaStreamHeader: return "Invalid Java serialization header"
        case .unexpectedToken(let tok, let pos): return String(format: "Unexpected token 0x%02X at offset %d", tok, pos)
        case .parsingFailed(let msg): return "Parsing failed: \(msg)"
        }
    }
}

fileprivate final class JavaClassDesc {
    let name: String
    let flags: UInt8
    var fields: [JavaFieldDesc] = []
    var superDesc: JavaClassDesc?

    init(name: String, flags: UInt8) {
        self.name = name
        self.flags = flags
    }
}

fileprivate struct JavaFieldDesc {
    let name: String
    let typeCode: Character
    let fieldType: Any?
}

fileprivate final class ParsedJavaObject {
    let className: String
    var values: [String: Any] = [:]
    var elements: [Any] = []

    init(className: String) {
        self.className = className
    }
}

public class QASetUnpacker {
    private static let magicHeader = Data([0x51, 0x41, 0x53, 0x45, 0x54, 0x01]) // "QASET\x01"

    public static func isQASet(data: Data) -> Bool {
        guard data.count >= magicHeader.count else { return false }
        return data.prefix(magicHeader.count) == magicHeader
    }

    public static func decompressGzip(_ data: Data) throws -> Data {
        var stream = z_stream()
        let initStatus = inflateInit2_(&stream, 16 + MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw QASetUnpackerError.decompressionFailed(initStatus)
        }
        defer { inflateEnd(&stream) }

        var decompressed = Data()
        let bufferSize = 65536
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        try data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress.assumingMemoryBound(to: Bytef.self))
            stream.avail_in = uInt(data.count)

            var status = Z_OK
            while status == Z_OK {
                status = buffer.withUnsafeMutableBytes { (outBuf: UnsafeMutableRawBufferPointer) -> Int32 in
                    stream.next_out = outBuf.baseAddress?.assumingMemoryBound(to: Bytef.self)
                    stream.avail_out = uInt(bufferSize)

                    let ret = inflate(&stream, Z_NO_FLUSH)
                    let count = bufferSize - Int(stream.avail_out)
                    if count > 0, let ptr = outBuf.baseAddress {
                        decompressed.append(ptr.assumingMemoryBound(to: UInt8.self), count: count)
                    }
                    return ret
                }
            }
            if status != Z_STREAM_END && status != Z_OK {
                throw QASetUnpackerError.decompressionFailed(status)
            }
        }
        return decompressed
    }

    public static func unpackToExamPaper(data: Data) throws -> ExamPaper {
        var payload = data
        if isQASet(data: data) {
            let compressed = data.dropFirst(magicHeader.count)
            payload = try decompressGzip(compressed)
        }

        let parser = JavaStreamParser(data: payload)
        guard let rootObj = try parser.readObject() as? ParsedJavaObject else {
            throw QASetUnpackerError.parsingFailed("Root object is not a Java Object")
        }

        let id = rootObj.values["id"] as? String ?? UUID().uuidString
        let title = rootObj.values["title"] as? String ?? "Exam Paper"
        let date = rootObj.values["date"] as? String ?? ""
        let totalMarks = (rootObj.values["totalMarks"] as? Int32).map(Int.init) ?? 100
        let generationMode = rootObj.values["generationMode"] as? String ?? "HONOURS"
        let promptSetUsed = rootObj.values["promptSetUsed"] as? String
        let cachedQuestionCount = (rootObj.values["cachedQuestionCount"] as? Int32).map(Int.init) ?? 0
        let cachedAnsweredCount = (rootObj.values["cachedAnsweredCount"] as? Int32).map(Int.init) ?? 0

        var questions: [ExamQuestion] = []
        if let qContainer = rootObj.values["questions"] as? ParsedJavaObject {
            for elem in qContainer.elements {
                if let qObj = elem as? ParsedJavaObject {
                    let qId = qObj.values["id"] as? String ?? UUID().uuidString
                    let qNum = qObj.values["number"] as? String ?? "Q1"
                    let qText = qObj.values["text"] as? String ?? ""
                    let qMarks = (qObj.values["marks"] as? Int32).map(Int.init) ?? 10
                    let isMcq = qObj.values["isMcq"] as? Bool ?? false
                    let correctOpt = qObj.values["correctOption"] as? String ?? ""
                    let ans = qObj.values["honoursAnswer"] as? String ?? ""
                    let status = qObj.values["status"] as? String ?? "COMPLETED"

                    var mcqOptions: [String] = []
                    if let mcqContainer = qObj.values["mcqOptions"] as? ParsedJavaObject {
                        mcqOptions = mcqContainer.elements.compactMap { $0 as? String }
                    }

                    questions.append(ExamQuestion(
                        id: qId,
                        number: qNum,
                        text: qText,
                        marks: qMarks,
                        isMcq: isMcq,
                        mcqOptions: mcqOptions,
                        correctOption: correctOpt,
                        honoursAnswer: ans,
                        status: status
                    ))
                }
            }
        }

        return ExamPaper(
            id: id,
            title: title,
            date: date,
            totalMarks: totalMarks,
            generationMode: generationMode,
            promptSetUsed: promptSetUsed,
            questions: questions,
            cachedQuestionCount: cachedQuestionCount > 0 ? cachedQuestionCount : questions.count,
            cachedAnsweredCount: cachedAnsweredCount > 0 ? cachedAnsweredCount : questions.filter { $0.isAnswered }.count
        )
    }
}

fileprivate final class JavaStreamParser {
    private let data: Data
    private var pos: Int = 0
    private var handles: [Any] = []

    init(data: Data) {
        self.data = data
    }

    func readByte() throws -> UInt8 {
        guard pos < data.count else { throw QASetUnpackerError.parsingFailed("Unexpected end of stream") }
        let b = data[pos]
        pos += 1
        return b
    }

    func readBytes(_ count: Int) throws -> Data {
        guard pos + count <= data.count else { throw QASetUnpackerError.parsingFailed("Unexpected end of stream") }
        let sub = data.subdata(in: pos..<(pos + count))
        pos += count
        return sub
    }

    func readUInt16() throws -> UInt16 {
        let b = try readBytes(2)
        return (UInt16(b[b.startIndex]) << 8) | UInt16(b[b.startIndex + 1])
    }

    func readInt32() throws -> Int32 {
        let b = try readBytes(4)
        let u = (UInt32(b[b.startIndex]) << 24) |
                (UInt32(b[b.startIndex + 1]) << 16) |
                (UInt32(b[b.startIndex + 2]) << 8) |
                UInt32(b[b.startIndex + 3])
        return Int32(bitPattern: u)
    }

    func readUTF() throws -> String {
        let len = Int(try readUInt16())
        let b = try readBytes(len)
        return String(data: b, encoding: .utf8) ?? ""
    }

    func readObject() throws -> Any? {
        if pos == 0 {
            let magic = try readUInt16()
            let ver = try readUInt16()
            guard magic == 0xACED, ver == 5 else {
                throw QASetUnpackerError.invalidJavaStreamHeader
            }
        }

        let tc = try readByte()
        switch tc {
        case 0x70: // TC_NULL
            return nil

        case 0x71: // TC_REFERENCE
            let ref = Int(try readInt32()) - 0x7E0000
            guard ref >= 0, ref < handles.count else {
                throw QASetUnpackerError.parsingFailed("Invalid object reference handle \(ref)")
            }
            return handles[ref]

        case 0x74: // TC_STRING
            let s = try readUTF()
            handles.append(s)
            return s

        case 0x7C: // TC_LONGSTRING
            let b = try readBytes(8)
            var len: UInt64 = 0
            for byte in b { len = (len << 8) | UInt64(byte) }
            let strData = try readBytes(Int(len))
            let s = String(data: strData, encoding: .utf8) ?? ""
            handles.append(s)
            return s

        case 0x72: // TC_CLASSDESC
            let name = try readUTF()
            _ = try readBytes(8) // serialVersionUID
            let flags = try readByte()
            let numFields = Int(try readUInt16())
            let cd = JavaClassDesc(name: name, flags: flags)
            handles.append(cd)

            for _ in 0..<numFields {
                let typeCode = Character(UnicodeScalar(try readByte()))
                let fname = try readUTF()
                var ftype: Any? = nil
                if typeCode == "L" || typeCode == "[" {
                    ftype = try readObject()
                }
                cd.fields.append(JavaFieldDesc(name: fname, typeCode: typeCode, fieldType: ftype))
            }
            guard try readByte() == 0x78 else { // TC_ENDBLOCKDATA
                throw QASetUnpackerError.unexpectedToken(0, pos)
            }
            cd.superDesc = try readObject() as? JavaClassDesc
            return cd

        case 0x73: // TC_OBJECT
            guard let cd = try readObject() as? JavaClassDesc else {
                throw QASetUnpackerError.parsingFailed("Expected class descriptor for TC_OBJECT")
            }
            let obj = ParsedJavaObject(className: cd.name)
            handles.append(obj)

            for f in cd.fields {
                switch f.typeCode {
                case "I":
                    obj.values[f.name] = try readInt32()
                case "Z":
                    obj.values[f.name] = (try readByte() != 0)
                case "L", "[":
                    obj.values[f.name] = try readObject()
                default:
                    throw QASetUnpackerError.parsingFailed("Unsupported field type \(f.typeCode)")
                }
            }

            if cd.name == "java.util.ArrayList" {
                guard try readByte() == 0x77 else { // TC_BLOCKDATA
                    throw QASetUnpackerError.parsingFailed("Expected TC_BLOCKDATA for ArrayList")
                }
                _ = try readByte() // block length
                let capacity = Int(try readInt32())
                var elements: [Any] = []
                for _ in 0..<capacity {
                    if let elem = try readObject() {
                        elements.append(elem)
                    }
                }
                guard try readByte() == 0x78 else { // TC_ENDBLOCKDATA
                    throw QASetUnpackerError.parsingFailed("Expected TC_ENDBLOCKDATA for ArrayList")
                }
                obj.elements = elements
            }
            return obj

        case 0x77: // TC_BLOCKDATA
            let len = Int(try readByte())
            return try readBytes(len)

        case 0x78: // TC_ENDBLOCKDATA
            return nil

        default:
            throw QASetUnpackerError.unexpectedToken(tc, pos)
        }
    }
}
