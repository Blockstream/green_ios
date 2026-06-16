import core

actor SwapManager {
    static let shared = SwapManager()
    private var activeTasks: Set<String> = []
    private var backends: [String: LwkBoltzBackend] = [:]

    func shouldStartTask(for id: String) -> Bool {
        if activeTasks.contains(id) { return false }
        activeTasks.insert(id)
        return true
    }

    func finishTask(for id: String) {
        activeTasks.remove(id)
    }

    // Shared session logic to save memory
    func getBackend(for xpubHash: String) -> LwkBoltzBackend {
        if let existing = backends[xpubHash] { return existing }
        let new = LwkBoltzBackend()
        backends[xpubHash] = new
        return new
    }
}
