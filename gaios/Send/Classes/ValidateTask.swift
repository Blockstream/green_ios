import Foundation
import PromiseKit

enum InputType {
    case transaction
    case sweep
    case bumpFee
}

class ValidateTask {
    var tx: Transaction?
    private var cancelme = false
    private var task: DispatchWorkItem?

    init(details: [String: Any], inputType: InputType) {

        task = DispatchWorkItem {
            var newDetails = details

            if inputType == .transaction {
                let unspentCall = try? SessionManager.shared.getUnspentOutputs(details: ["subaccount": details["subaccount"] ?? 0, "num_confs": 0])
                let unspentData = try? unspentCall?.resolve().wait()
                let unspentResult = unspentData?["result"] as? [String: Any]
                let unspent = unspentResult?["unspent_outputs"] as? [String: Any]
                newDetails["utxos"] = unspent ?? [:]
            }

            let createCall = try? SessionManager.shared.createTransaction(details: newDetails)
            let createData = try? createCall?.resolve().wait()
            let createResult = createData?["result"] as? [String: Any]
            self.tx = Transaction(createResult ?? [:])
        }
    }

    func execute() -> Promise<Transaction?> {
        let bgq = DispatchQueue.global(qos: .background)
        return Promise<Transaction?> { seal in
            self.task!.notify(queue: bgq) {
                guard !self.cancelme else { return seal.reject(PMKError.cancelled) }
                seal.fulfill(self.tx)
            }
            bgq.async(execute: self.task!)
        }
    }

    func cancel() {
        cancelme = true
        task?.cancel()
    }
}
