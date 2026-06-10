import Observation
import CCTransCore

@MainActor
@Observable
final class PopupViewModel {
    enum State: Equatable {
        case loading
        case result(TranslationResult)
        case error(String)
    }
    var state: State = .loading
}
