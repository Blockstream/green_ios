protocol SendFlowErrorDisplayable: AnyObject {
    @MainActor
    func handleSendFlowError(_ error: Error?)
}
