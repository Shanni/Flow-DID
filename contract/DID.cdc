import NonFungibleToken from "./standards/NonFungibleToken"

pub contract DIDContract: NonFungibleToken {

    pub var total: UInt64

    /// Storage and Public Paths
    pub let CollectionStoragePath: StoragePath
    pub let CollectionPublicPath: PublicPath
    pub let MinterStoragePath: StoragePath

    /// The event that is emitted when the contract is created
    pub event ContractInitialized()

    pub resource DID {
        pub let id: String
        pub let publicKey: String

        init(id: String, publicKey: String) {
            self.id = id
            self.publicKey = publicKey
        }
    }

    pub resource DIDCollection {
        pub var dids: @{String: DID}

        init() {
            self.dids <- {}
        }
        
        destroy () {
            destroy self.dids
        }
    }

    pub fun createDID(publicKey: String): @DID {
        // create a random id for the DID
        let id = unsafeRandom().toString().concat(getCurrentBlock().timestamp.toString())

        let did <- create DID(id: id, publicKey: publicKey)

        // Get or create the DIDCollection
        let collection <- self.account(DIDContract.address)
            .getCapability<&DIDCollection>(DIDCollection.CollectionPath)
            .borrow()
            ?? panic("Could not borrow capability to DIDCollection")

        collection.dids[id] = <-did

        self.getAccount(DIDContract.address)
            .getCapability<&DIDCollection>(DIDCollection.CollectionPath)
            .borrow<&DIDCollection.Collection{DIDCollection}>().save(<-collection)

        return <-did
    }

    pub fun getDID(id: String): @DID? {
        let collection = self.getAccount(DIDContract.address)
            .getCapability<&DIDCollection>(DIDCollection.CollectionPath)
            .borrow()
            ?? panic("Could not borrow capability to DIDCollection")

        return collection.dids[id]
    }

    pub fun verifySignature(didId: String, message: String, signature: String): Bool {
        let did = self.getDID(didId)

        if let publicKey = did?.publicKey {
            // Verify the signature using the publicKey and signature
            // Implement the signature verification algorithm here
            return true // Return true if the signature is valid
        }

        return false // Return false if the DID doesn't exist
    }

        pub resource DIDMinter {

        /// Mints a new DID with a new ID and deposit it in the
        /// recipients collection using their collection reference
        ///
        /// @param recipient: A capability to the collection where the new DID will be deposited

        pub fun mintDID(
            recipient: &{NonFungibleToken.CollectionPublic},
        ) {
            let metadata: {String: AnyStruct} = {}
            let currentBlock = getCurrentBlock()
            metadata["mintedBlock"] = currentBlock.height
            metadata["mintedTime"] = currentBlock.timestamp
            metadata["minter"] = recipient.owner!.address

            // this piece of metadata will be used to show embedding rarity into a trait
            metadata["foo"] = "bar"

            // create a new DID
            var newDID <- DIDContract.createDID()
            
            // deposit it in the recipient's account using their reference
            recipient.deposit(token: <-newDID)

            DIDContract.total = DIDContract.total + UInt64(1)
        }
    }

    init() {

        self.total = 0

        // Set the named paths
        self.CollectionStoragePath = /storage/DIDCollection
        self.CollectionPublicPath = /public/PubDIDCollection
        self.MinterStoragePath = /storage/DIDMinter

        // Create a Collection resource and save it to storage
        let collection <- create DIDCollection()
        self.account.save(<-collection, to: self.CollectionStoragePath)

        // create a public capability for the collection
        self.account.link<&DIDContract.DIDCollection{}>(
            self.CollectionPublicPath,
            target: self.CollectionStoragePath
        )

        // Create a Minter resource and save it to storage
        let minter <- create DIDMinter()
        self.account.save(<-minter, to: self.MinterStoragePath)

        emit ContractInitialized()
    }
}
