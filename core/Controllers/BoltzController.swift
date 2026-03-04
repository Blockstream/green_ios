import Foundation
import CoreData

public actor BoltzController {
    private let modelName = "BoltzDataModel"
    private static let appGroupIdentifier = Bundle.main.appGroup
    public static let shared = BoltzController()
    let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    public init() {
        // Locate the Shared App Group Container
        guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "\(Self.appGroupIdentifier)") else {
            fatalError("Could not retrieve shared application group container URL. Check App Group configuration.")
        }
        let storeURL = groupURL.appendingPathComponent("\(self.modelName).sqlite")
        // Ensure the directory exists and has the right permissions
        let folderURL = storeURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: [
            .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
        ])
        // Set persistent store
        let storeDescription = NSPersistentStoreDescription(url: storeURL)
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        // Enable Persistent History Tracking
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        // Set File Protection
        storeDescription.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                                       forKey: NSPersistentStoreFileProtectionKey)
        // Create container
        container = NSPersistentContainer(name: self.modelName)
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // Handle the error appropriately, usually by crashing in development
                // but logging and failing gracefully in production.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            logger.info("Successfully loaded persistent store: \(storeDescription.url?.lastPathComponent ?? "Unknown")")
        }
        self.context = container.newBackgroundContext()
        // Handle Conflicts
        self.context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.context.automaticallyMergesChangesFromParent = true
    }

    /// Creates and saves a new 'BoltzSwaps' object.
    public func create(id: String?, data: String?, isPending: Bool, xpubHashId: String?, invoice: String?, swapType: SwapType, txHash: String?) async throws -> BoltzSwap {
        let savedItem: BoltzSwap = try await context.perform {
            let item = BoltzSwap(context: self.context)
            item.id = id
            item.data = data
            item.isPending = isPending
            item.invoice = invoice
            item.xpubHashId = xpubHashId
            item.swapType = swapType.rawValue
            item.txHash = txHash
            try self.context.save()
            return item
        }
        return savedItem
    }
    
    public func fetchIDs(_ predicates: [NSPredicate]) async throws -> [NSManagedObjectID] {
        let ids: [NSManagedObjectID] = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: "BoltzSwap")
            if !predicates.isEmpty {
                fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            fetchRequest.resultType = .managedObjectIDResultType
            let ids = try self.context.fetch(fetchRequest)
            return ids
        }
        return ids
    }
    public func fetchPendingSwaps(xpubHashId: String) async throws -> [NSManagedObjectID] {
        try await fetchIDs([
            NSPredicate(format: "xpubHashId == %@", xpubHashId),
            NSPredicate(format: "isPending == true"),
            NSPredicate(format: "txHash == nil")
        ])
    }
    public func fetchSwaps(xpubHashId: String, invoice: String, swapType: BoltzSwapTypes) async throws -> [NSManagedObjectID] {
        try await fetchIDs([
            NSPredicate(format: "xpubHashId == %@", xpubHashId),
            NSPredicate(format: "invoice == %@", invoice),
            NSPredicate(format: "swapType == %@", swapType.rawValue)
        ])
    }
    
    /// Fetch ID of 'BoltzSwap' objects by his id.
    public func fetchID(byId id: String) async throws -> NSManagedObjectID? {
        let item = try await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: "BoltzSwap")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id)
            fetchRequest.fetchLimit = 1
            fetchRequest.resultType = .managedObjectIDResultType
            let ids = try self.context.fetch(fetchRequest)
            return ids.first
        }
        return item
    }

    public func upsert(id: String, data: String, isPending: Bool, xpubHashId: String, invoice: String? = nil, swapType: SwapType, txHash: String?) async throws {
        if let persistentID = try? await BoltzController.shared.fetchID(byId: id) {
            try? await update(with: persistentID, newData: data, newIsPending: isPending, newTxHash: txHash)
        } else {
            _ = try? await create(id: id, data: data, isPending: true, xpubHashId: xpubHashId, invoice: invoice, swapType: swapType, txHash: txHash)
        }
    }

    /// Fetch object of a 'BoltzSwap' from his id.
    public func get(with id: NSManagedObjectID) async throws -> BoltzSwap? {
        // objectWithID: efficiently uses in-memory information or the store as needed
        try await context.perform {
            try self.context.existingObject(with: id) as? BoltzSwap
        }
    }

    public func gets(with ids: [NSManagedObjectID]) async throws -> [BoltzSwap] {
        if ids.isEmpty {
            return []
        }
        return try await context.perform {
            try ids.compactMap { id in
                try self.context.existingObject(with: id) as? BoltzSwap
            }
        }
    }

    /// Updates the 'data' attribute of an existing 'BoltzSwap' by its ID.
    public func update(with id: NSManagedObjectID, newData: String? = nil, newIsPending: Bool? = nil, newTxHash: String? = nil) async throws {
        try await context.perform {
            let object = self.context.object(with: id)
            guard let boltzSwap = object as? BoltzSwap else {
                // It's good practice to check if the object exists and is the correct type.
                throw NSError(domain: "BoltzControllerError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Item not found or wrong type for given ID"])
            }
            if let newData {
                boltzSwap.data = newData
            }
            if let newIsPending {
                boltzSwap.isPending = newIsPending
            }
            if let newTxHash {
                boltzSwap.txHash = newTxHash
            }
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
    /// Deletes an item based on its PersistentID.
    public func delete(with id: NSManagedObjectID) async throws {
        try await context.perform {
            let object = self.context.object(with: id)
            self.context.delete(object)
            if self.context.hasChanges {
                try self.context.save()
            }
        }
    }
}
