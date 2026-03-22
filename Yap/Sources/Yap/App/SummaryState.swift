import Foundation

/// Observable state for a session's AI summary.
enum SummaryState {
    case loading
    case ready(SummaryEngine.PersistedSummary)
    case failed(String)   // error message for display
}
