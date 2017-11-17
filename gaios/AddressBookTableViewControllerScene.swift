//
//  AddressBookTableViewControllerScene.swift
//  gaios
//

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
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Address Book"
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
