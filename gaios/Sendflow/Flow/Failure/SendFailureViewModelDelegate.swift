
protocol SendFailureViewModelDelegate: AnyObject {
    @MainActor
    func sendFailureViewModelDismiss(_ vm: SendFailureViewModel)
    @MainActor
    func sendFailureViewModelDidAgain(_ vm: SendFailureViewModel)
    @MainActor
    func sendFailureViewModelDidSupport(_ vm: SendFailureViewModel, error: Error)
}
