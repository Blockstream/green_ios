import greenaddress
import hw

extension WalletManager {

    func resolveParentXpub(
        credentials: Credentials,
        parentXpub: String?
    ) async throws -> String? {
        if credentials.isWatchonly {
            return parentXpub
        }
        return try await getWalletIdentifier(credentials: credentials)?.xpubHashId
    }

    func getWalletIdentifier(credentials: Credentials, networkId: NetworkId) throws -> WalletIdentifier? {
        return try prominentSession?
            .getWalletIdentifier(
                gdkNetwork: networkId.gdkNetwork.network,
                credentials: credentials
            )
    }

    public func loginNetworkBackend(
        backend: NetworkBackend,
        credentials: Credentials,
        lightningCredentials: Credentials?,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool,
        resolvedParentXpub: String?)
    async throws -> LoginUserResult? {
        try await backend
            .connect(params: createConnectionParams(network: backend.network))
        if let backend = backend as? GdkNetworkBackend {
            logger.info("Connecting to gdk backend \(backend.network.network)")
            return try await backend.login(
                credentials: credentials,
                device: device,
                fullRestore: fullRestore,
                creation: creation,
                prominentNetworkId: prominentNetworkId
            )
        } else if let backend = backend as? GlNetworkBackend, let lightningCredentials {
            logger.info("Connecting to gl backend \(backend.network.network)")
            guard let parentXpub = resolvedParentXpub else {
                return nil
            }
            return try await backend.login(
                credentials: lightningCredentials,
                restore: fullRestore,
                parentXpub: parentXpub)
        } else if let backend = backend as? LwkNetworkBackend {
            logger.info("Connecting to lwk backend \(backend.network.network)")
            // disable watchonly for lwk
            if credentials.isWatchonly {
                return nil
            }
            return try await backend.login(
                credentials: credentials
            )
        }
        return nil
    }

    public func loginLwkBoltz(boltzCredentials: Credentials, xpubHashId: String) {
        deferredLwkLoginTask?.cancel()
        deferredLwkLoginTask = Task(priority: .high) { [weak lwkBoltzBackend] in
            _ = try await lwkBoltzBackend?.loginUser(boltzCredentials, xpubHashId: xpubHashId)
        }
    }

    public func login(
        credentials: Credentials,
        lightningCredentials: Credentials?,
        boltzCredentials: Credentials?,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool,
        parentXpub: String? = nil
    ) async throws -> LoginUserResult? {
        isEphemeral = !(credentials.bip39Passphrase ?? "").isEmpty
        isWatchonly = credentials.isWatchonly
        hwDevice = device
        let resolvedParentXpub = try await resolveParentXpub(
            credentials: credentials,
            parentXpub: parentXpub
        )
        networkErrors.removeAll()
        let outcomes: [(NetworkId, Result<LoginUserResult?, Error>)] = await withTaskGroup(
            of: (NetworkId, Result<LoginUserResult?, Error>).self
        ) { group in
            for (networkId, backend) in networkBackends {
                group.addTask(priority: .high) {
                    do {
                        let res = try await self.loginNetworkBackend(
                            backend: backend,
                            credentials: credentials,
                            lightningCredentials: lightningCredentials,
                            device: device,
                            fullRestore: fullRestore,
                            creation: creation,
                            resolvedParentXpub: resolvedParentXpub)
                        return (networkId, .success(res))
                    } catch {
                        return (networkId, .failure(error))
                    }
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
        var loginUserDatas: [NetworkId: LoginUserResult?] = [:]
        for (networkId, outcome) in outcomes {
            switch outcome {
            case .success(let res):   loginUserDatas[networkId] = res
            case .failure(let error): networkErrors[networkId] = error
            }
        }
        let loggedBackends = networkBackends.filter { $0.value.isLoggedIn }
        logger.info("WM sessions: \(loggedBackends.count)")
        if loggedBackends.count == 0 {
            throw LoginError.failed()
        }
        let accounts = try await updateAccounts()
        logger.info("WM subaccounts: \(accounts.count)")
        let prominentResult = loginUserDatas.first { $0.key == prominentNetworkId }?.value
        if let boltzCredentials, let gdkResult = prominentResult {
            loginLwkBoltz(boltzCredentials: boltzCredentials, xpubHashId: gdkResult.xpubHashId)
        }
        try? await self.syncSettings(restore: fullRestore)
        return prominentResult
    }
}
