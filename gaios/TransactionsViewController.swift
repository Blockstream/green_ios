//
//  TransactionsViewController.swift
//  gaios
//
//  Created by luca on 16/11/2018.
//  Copyright © 2018 Blockstream Corporation. All rights reserved.
//

import Foundation
import UIKit

class TransactionsController: UITableViewController {

    var presentingWallet: WalletItem? = nil
    var items = [TransactionItem]()

    override func viewDidLoad() {
        super.viewDidLoad()

        let nib = UINib(nibName: "TransactionTableCell", bundle: nil)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.tableFooterView = UIView()
        self.tableView.register(nib, forCellReuseIdentifier: "TransactionTableCell")
        self.tableView.allowsSelection = true
        self.tableView.isUserInteractionEnabled = true
        self.tableView.separatorColor = UIColor.customTitaniumLight()
        tableView.tableHeaderView = getWalletCardView()
        loadTransations()
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    public override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 65
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TransactionTableCell", for: indexPath) as! TransactionTableCell
        let item: TransactionItem = items.reversed()[indexPath.row]
        cell.amount.text = item.amount
        if(item.type == "incoming" || item.type == "redeposit") {
            cell.address.text = presentingWallet?.name
            cell.amount.textColor = UIColor.customMatrixGreen()
        } else {
            cell.address.text = item.address
            cell.amount.textColor = UIColor.white
        }

        if(item.blockheight == 0) {
            cell.status.text = NSLocalizedString("id_unconfirmed", comment: "")
            cell.status.textColor = UIColor.red
        } else if (AccountStore.shared.getBlockheight() - item.blockheight < 6) {
            let confirmCount = AccountStore.shared.getBlockheight() - item.blockheight + 1
            cell.status.text = String(format: "(%d/6)", confirmCount)
            cell.status.textColor = UIColor.red
        } else {
            cell.status.text = NSLocalizedString("id_completed", comment: "")
            cell.status.textColor = UIColor.customTitaniumLight()
        }
        cell.selectionStyle = .none
        cell.date.text = item.date
        cell.separatorInset = UIEdgeInsetsMake(0, 0, 0, 0)
        return cell;
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item: TransactionItem = items.reversed()[indexPath.row]
        showTransaction(tx: item)
    }

/*
    override func tableView(_ tableView: UITableView, /viewForHeaderInSection section: Int) -> UIView? {
        let  walletCell = tableView.dequeueReusableCell(withIdentifier: "WalletCardHeader") as! WalletCardHeader
        walletCell.nameLabel.text = presentingWallet?.name
        walletCell.balanceLabel.text = presentingWallet?.balance
        return walletCell
    }
*/
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    // load data
    func loadTransations() {
        items.removeAll(keepingCapacity: true)
        AccountStore.shared.GDKQueue.async{
            wrap {
                try getSession().getTransactions(subaccount: (self.presentingWallet?.pointer)!, page: 0)
                }.done { (transactions: [String : Any]?) in
                    DispatchQueue.main.async {
                        let list = transactions!["list"] as! NSArray
                        for tx in list.reversed() {
                            let transaction = tx as! [String : Any]
                            let satoshi:UInt64 = transaction["satoshi"] as! UInt64
                            let hash = transaction["txhash"] as! String
                            let fee = transaction["fee"] as! UInt32
                            let size = transaction["transaction_vsize"] as! UInt32
                            let blockheight = transaction["block_height"] as! UInt32
                            let memo = transaction["memo"] as! String

                            let dateString = transaction["created_at"] as! String
                            let type = transaction["type"] as! String
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .medium
                            dateFormatter.timeStyle = .short
                            let date = Date.dateFromString(dateString: dateString)
                            let formattedBalance: String = String.formatBtc(satoshi: satoshi)
                            let adressees = transaction["addressees"] as! [String]
                            let can_rbf = transaction["can_rbf"] as! Bool
                            var counterparty = ""
                            if (adressees.count > 0) {
                                counterparty = adressees[0]
                            }
                            let formatedTransactionDate = Date.dayMonthYear(date: date)
                            let item = TransactionItem(timestamp: dateString, address: counterparty, amount: formattedBalance, fiatAmount: "", date: formatedTransactionDate, btc: Double(satoshi), type: type, hash: hash, blockheight: blockheight, fee: fee, size: size, memo: memo, dateRaw: date, canRBF: can_rbf, rawTransaction: transaction)
                            self.items.append(item)
                        }
                        print("success")
                    }
                }.ensure {
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }.catch { error in
                    print("error")
            }
        }
    }

    func getWalletCardView() -> WalletCardHeader? {
        guard let wallet: WalletItem = presentingWallet! else { return nil }


        let view: WalletCardHeader = ((Bundle.main.loadNibNamed("WalletCardHeader", owner: self, options: nil)![0] as? WalletCardHeader)!)

        view.balanceLabel.text = String.formatBtc(satoshi: UInt64(wallet.balance)!)
        view.addressLabel.text = wallet.address
        view.nameLabel.text = wallet.name
        view.index = Int(wallet.pointer)
        view.wallet = wallet
        view.balanceLabel.textColor = UIColor.white
        view.nameLabel.textColor = UIColor.white
        let uri = bip21Helper.btcURIforAddress(address: wallet.address)
        view.qrImageView.image = QRImageGenerator.imageForTextDark(text: uri, frame: view.qrImageView.frame)

        let tap = UITapGestureRecognizer(target: self, action: #selector(zoomQR))
        view.qrImageView.isUserInteractionEnabled = true
        view.qrImageView.addGestureRecognizer(tap)

        view.receiveButton.addTarget(self, action: #selector(self.receiveToWallet(_:)), for: .touchUpInside)
        view.sendButton.addTarget(self, action: #selector(self.sendfromWallet(_:)), for: .touchUpInside)

        return view
    }


    @objc func sendfromWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "send", sender: self)
    }

    @objc func receiveToWallet(_ sender: UIButton) {
        self.performSegue(withIdentifier: "receive", sender: self)
    }

    func showTransaction(tx: TransactionItem) {
        self.performSegue(withIdentifier: "detail", sender: tx)
    }

    @objc func zoomQR(recognizer: UITapGestureRecognizer) {
        self.performSegue(withIdentifier: "address", sender: self)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let nextController = segue.destination as? SendBtcViewController {
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? ReceiveBtcViewController {
            nextController.receiveAddress = presentingWallet?.address
            nextController.wallet = presentingWallet
        } else if let nextController = segue.destination as? TransactionDetailViewController {
            nextController.transaction_g = sender as? TransactionItem
            nextController.pointer = presentingWallet!.pointer
        } else if let addressDetail = segue.destination as? AddressDetailViewController {
            addressDetail.wallet = presentingWallet
            addressDetail.providesPresentationContextTransitionStyle = true
            addressDetail.definesPresentationContext = true
            addressDetail.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            addressDetail.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        } else if let nextController = segue.destination as? TransactionsController {
            nextController.presentingWallet = presentingWallet
        }
    }
}
