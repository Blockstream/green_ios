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
        return try prominentSession
            .getWalletIdentifier(
                netParams: createConnectionParams(
                    network: networkId.gdkNetwork
                ),
                credentials: credentials
            )
    }

    public func loginGdk(
        backend: GdkNetworkBackend,
        credentials: Credentials,
        device: HWDevice?,
        fullRestore: Bool,
        creation: Bool)
    async throws -> LoginUserResult? {
        let network = backend.network
        // Disable gdk login on multisig on new wallet
        if creation && network.multisig {
            return nil
        }
        // Disable gdl liquid login, if hw doesn't support it
        if network.liquid && device?.supportsLiquid ?? 1 == 0 {
            logger.error("WM login disable liquid if is unsupported on hw")
            return nil
        }
        // Access by multisig watchonly credentials
        if credentials.isWatchonly && network.multisig {
            if !credentials.username.isNilOrEmpty {
                let credentials = Credentials(
                    username: credentials.username,
                    password: credentials.password
                )
                return try await backend.login(credentials: credentials, device: nil)
            }
            return nil
        }
        // Access by singlesig watchonly credentials
        if credentials.isWatchonly && network.singlesig {
            let descriptors = credentials.coreDescriptors?.filter(
                { Wally.isDescriptor($0, for: network.networkId)
                })
            let slip132Keys = credentials.slip132ExtendedPubkeys?.filter({ Wally.isPubKey($0, for: network.networkId) })
            if !descriptors.isNilOrEmpty || !slip132Keys.isNilOrEmpty {
                let credentials = Credentials(
                    coreDescriptors: descriptors,
                    slip132ExtendedPubkeys: slip132Keys
                )
                return try await backend.login(credentials: credentials, device: nil)
            }
            return nil
        }
        // Read previous wallet cache
        guard let walletHashId = try await getWalletIdentifier(
            network: network,
            credentials: credentials
        )?.walletHashId else {
            throw GaError.GenericError("Wallet not found")
        }
        let hasGdkCache = Gdk.shared.hasGdkCache(
            walletHashId: walletHashId
        )
        // Access by software/hardware credentials
        do {
            let res = try await backend.login(credentials: credentials, device: device)
            let refresh = fullRestore || (!creation && !hasGdkCache)
            try? await discoveryAndSetupDefaultsAccounts(backend: backend, walletHashId: walletHashId, refresh: refresh, hasGdkCache: hasGdkCache)
            _ = try? await backend.session.loadSettings()
            return res
        } catch TwoFactorCallError.failure(let txt) {
            if txt.contains("HWW must enable host unblinding for singlesig wallets") {
                throw LoginError.hostUnblindingDisabled(txt)
            } else if txt == "id_login_failed" && network.electrum {
                throw LoginError.failed(txt)
            }
            return nil
        } catch {
            throw error
        }
    }
    func discoveryAndSetupDefaultsAccounts(backend: GdkNetworkBackend, walletHashId: String, refresh: Bool, hasGdkCache: Bool) async throws {
        let networkAccounts = try await backend.getAccounts(refresh: refresh)
        let walletIsFunded = !networkAccounts.filter {
            $0.bip44Discovered == true
        }.isEmpty 
        if walletIsFunded && refresh {
            // Archive no-history default account
            if let firstAccount = networkAccounts.first, firstAccount.pointer == 0 {
                let hasHistory = try await gdkAccountBackend(firstAccount).hasHistory()
                logger.info("WM \(backend.network.network) Archive no-history default account")
                if !hasHistory {
                    _ = try await updateAccount(
                        account: firstAccount,
                        isHidden: true,
                        newAccountName: firstAccount.type.title
                    )
                }
            }
        } else if !hasGdkCache { // Newly discovered Wallet
            // Archive GDK default account
            logger.info("WM \(backend.network.network) Archive GDK default account")
            if let defaultAccount = networkAccounts.first {
                _ = try await updateAccount(
                    account: defaultAccount,
                    isHidden: true,
                    newAccountName: defaultAccount.type.title
                )
            }
        }
        // Create GDK bip84Segwit account
        let defaultAccountBip84 = networkAccounts.filter(
            {$0.type == .bip84Segwit
            }).first
        if defaultAccountBip84 == nil {
            logger.info("WM \(backend.network.network) Create GDK bip84Segwit account")
            let accountType = AccountType.bip84Segwit
            _ = try await createAccount(
                network: backend.network,
                params: CreateSubaccountParams(
                    name: accountType.description,
                    type: accountType
                )
            )
        }
    }

    public func loginGl(
        backend: GlNetworkBackend,
        credentials: Credentials,
        restore: Bool,
        parentXpub: String
    )
    async throws -> LoginUserResult? {
        try await backend.login(
            credentials: credentials,
            isForceConnectAllowed: !restore,
            parentXpub: parentXpub)
        guard let walletId = try await getWalletIdentifier(
            credentials: credentials
        ) else {
            return nil
        }
        return LoginUserResult(
            xpubHashId: walletId.xpubHashId,
            walletHashId: walletId.walletHashId
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
            return try await loginGdk(
                backend: backend,
                credentials: credentials,
                device: device,
                fullRestore: fullRestore,
                creation: creation
            )
        } else if let backend = backend as? GlNetworkBackend, let lightningCredentials {
            logger.info("Connecting to gl backend \(backend.network.network)")
            guard let parentXpub = resolvedParentXpub else {
                return nil
            }
            return try await loginGl(
                backend: backend,
                credentials: lightningCredentials,
                restore: fullRestore,
                parentXpub: parentXpub)
        } else if let backend = backend as? LwkNetworkBackend {
            logger.info("Connecting to lwk backend \(backend.network.network)")
            // disable watchonly for lwk
            if credentials.isWatchonly {
                return nil
            }
            return try await loginLwk(
                backend: backend,
                credentials: credentials
            )
        }
        return nil
    }

    public func loginLwk(
        backend: LwkNetworkBackend,
        credentials: Credentials)
    async throws -> LoginUserResult? {
        guard credentials.mnemonic != nil else {
            // disable for hardware wallet
            return nil
        }
        guard let walletId = try await getWalletIdentifier(
            credentials: credentials
        ) else {
            return nil
        }
        try await backend
            .login(
                credentials: credentials
            )
        return LoginUserResult(
            xpubHashId: walletId.xpubHashId,
            walletHashId: walletId.walletHashId
        )
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
        //try? await self.syncSettings(restore: fullRestore)
        return prominentResult
    }
}
