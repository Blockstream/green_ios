//
//  SendTableViewControllerScene.swift
//  gaios
//

import UIKit

fileprivate class UserData {
    var recipient = String()
}

class SendTableCell: UITableViewCell {
    fileprivate weak var userData: UserData?
}

class SendAmountTableCell: SendTableCell {
}

class SendToTableCell: SendTableCell, UITextFieldDelegate {

    @IBOutlet weak var recipient: UITextField!

    fileprivate override weak var userData: UserData? {
        didSet {
            recipient.text = userData?.recipient
        }
    }

    override func awakeFromNib() {
        super .awakeFromNib()

        recipient.delegate = self
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return textField.resignFirstResponder()
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        userData!.recipient = textField.text ?? String()
    }
}

class SendFeeChoiceTableCell: SendTableCell {

    @IBOutlet weak var feeChoice: UISegmentedControl!

    @IBAction func feeAction(_ sender: Any) {
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedSegmentIndex = ["High": 0, "Normal": 1, "Low": 2, "Economy": 3][getGAService().getConfirmationPriority()]!
        let textAttrs = NSDictionary(object: UIFont.systemFont(ofSize: 9), forKey: NSAttributedStringKey.font as NSCopying)

        feeChoice.selectedSegmentIndex = selectedSegmentIndex
        feeChoice.setTitleTextAttributes(textAttrs as [NSObject : AnyObject] , for: .normal)
    }
}

class SendButtonTableCell: SendTableCell {

    @IBAction func sendAction(_ sender: Any) {
        try! getSession().send(addrAmt: [("2N5fRYGVs5Rj9dP32SwyWUrgeyt8cHJacpc", 1000)], feeRate: 1000, sendAll: false)
    }
}

class SendTableViewModel: NSObject {
    let cellIdentifiers = ["SendAmountTableCell", "SendToTableCell", "SendFeeChoiceTableCell", "SendButtonTableCell"]

    fileprivate var userData = UserData()

    func updateFromQRCode(_ qrcode: String) {
        userData.recipient = qrcode
    }
}

extension SendTableViewModel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Main"
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cellIdentifiers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifiers[indexPath.row], for: indexPath) as! SendTableCell
        cell.userData = userData
        return cell
    }
}

class SendTableViewControllerScene: UITableViewController, QRCodeReaderData {
    fileprivate let viewModel = SendTableViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = viewModel

        tableView.tableHeaderView = UIView()
        tableView.tableFooterView = UIView()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "QRCodeReaderViewController" {
            let qrCodeReaderViewController = segue.destination as! QRCodeReaderViewController
            qrCodeReaderViewController.sendControllerDelegate = self
        }
    }

    func onQRCodeReadSuccess(_ qrcode: String) {
        viewModel.updateFromQRCode(qrcode)

        self.tableView.reloadData()
    }

    func onQRCodeReadFailure() {
    }
}
