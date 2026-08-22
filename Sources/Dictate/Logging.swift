import OSLog

enum DictateLog {
    static let lifecycle = Logger(subsystem: "app.dictate.desktop", category: "lifecycle")
    static let capture = Logger(subsystem: "app.dictate.desktop", category: "capture")
    static let recognition = Logger(subsystem: "app.dictate.desktop", category: "recognition")
    static let delivery = Logger(subsystem: "app.dictate.desktop", category: "delivery")
    static let persistence = Logger(subsystem: "app.dictate.desktop", category: "persistence")
}
