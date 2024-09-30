import UIKit
extension UITableView {
    func reloadData(completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0, animations: reloadData) { _ in completion() }
    }
}
extension UITableView {
    func beginRefreshing() {
        guard let refreshControl = refreshControl, !refreshControl.isRefreshing else {
            return
        }
        refreshControl.beginRefreshing()
        refreshControl.sendActions(for: .valueChanged)
        let contentOffset = CGPoint(x: 0, y: -refreshControl.frame.height)
        setContentOffset(contentOffset, animated: true)
    }
    func endRefreshing() {
        refreshControl?.endRefreshing()
    }
}
