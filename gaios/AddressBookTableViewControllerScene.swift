import UIKit

class AddressBookItem {

}

class AddressBookTableViewModel: NSObject {
    var items = [AddressBookItem]()

    override init() {
        super.init()
    }
}

extension AddressBookTableViewModel: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        let label: UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: tableView.bounds.size.height))
        label.text = "You don't have any items right now"
        label.textAlignment = .center
        tableView.backgroundView = label
        return 0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AddressBookTableCell", for: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }
}

class AddressBookTableViewControllerScene: UITableViewController {
    fileprivate let viewModel = AddressBookTableViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableFooterView = UIView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}
