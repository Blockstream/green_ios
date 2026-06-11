import Foundation


protocol SendSuccessViewModelDelegate: AnyObject {
    @MainActor
    func sendSuccessViewModelDidShare(_ vm: SendSuccessViewModel, url: URL)
    @MainActor
    func sendSuccessViewModelDidFinish(_ vm: SendSuccessViewModel)
}
