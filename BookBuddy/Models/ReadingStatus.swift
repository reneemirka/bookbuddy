enum ReadingStatus: String, CaseIterable, Identifiable {
    case wantToRead, currentlyReading, read, didNotFinish
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wantToRead: "Want to Read"
        case .currentlyReading: "Currently Reading"
        case .read: "Read"
        case .didNotFinish: "Did Not Finish"
        }
    }
}
