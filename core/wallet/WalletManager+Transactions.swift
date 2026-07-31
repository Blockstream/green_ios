import greenaddress

extension WalletManager {

    public func transactions(subaccounts: [Account], first: Int = 0, count: Int = 30) async throws -> [Transaction] {
        var txs: [Transaction] = []
        for account in subaccounts {
            let params = GetTransactionsParams(
                subaccount: account.pointer,
                first: first, count: count
            )
            let gdkTxs = try await accountBackend(account).getTransactions(
                params: params
            )
            txs += gdkTxs.list.map { Transaction($0.details, accountId: account.id) }
        }
        return txs.sorted()
    }

    public func pagedTransactions(subaccounts: [Account], of page: Int = 0) async throws -> [String: Transactions] {
        var txs: [String: Transactions] = [:]
        for account in subaccounts {
            let params = GetTransactionsParams(
                subaccount: account.pointer,
                first: page * 30, count: 30
            )
            let gdkTxs = try await accountBackend(account)
                .getTransactions(params: params)
                .list
                .map { Transaction($0.details, accountId: account.id) }
            txs[account.id] = Transactions(list: gdkTxs)
        }
        return txs
    }

    func allBySubaccount(_ subaccount: Account) async throws -> [Transaction] {
        let offset = 30
        var page = 0
        var end: Bool = false
        var transactions: [Transaction] = []
        while end == false {
            let params = GetTransactionsParams(
                subaccount: subaccount.pointer,
                first: page * 30, count: 30
            )
            let gdkTxs = try await accountBackend(subaccount)
                .getTransactions(params: params)
                .list
                .map { Transaction($0.details, accountId: subaccount.id) }
            transactions.append(contentsOf: gdkTxs)
            if gdkTxs.count < offset {
                end = true
            } else {
                page += 1
            }
        }
        return transactions
    }
    public func allTransactions(subaccounts: [Account]) async throws -> [Transaction] {
        var txs: [Transaction] = []
        for account in subaccounts {
            let gdkTxs = try await self.allBySubaccount(account)
            txs += gdkTxs
        }
        return txs.sorted(by: { $0 > $1 })
    }

    public func cachedBalances(subaccounts: [Account]) -> [String: [String: Int64]] {
        subaccounts.reduce(into: [:]) { result, account in
            if let assets = accountBackendOrNil(account)?.assets {
                result[account.id] = assets
            }
        }
    }
    public func cachedTransactions(subaccounts: [Account]) -> [String: [Transaction]] {
        subaccounts.reduce(into: [:]) { result, account in
            result[account.id] = accountBackendOrNil(account)?.txs.values
                .map { Transaction($0.details, accountId: account.id) } ?? []
        }
    }

}
