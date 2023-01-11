import SotoS3
import SotoS3FileTransfer


struct LiveS3Client: S3Client {
    func deleteFile(client: AWSClient, logger: Logger, key: S3StoreKey) async throws {
        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let file = S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.delete(file)
    }

    func loadFile(client: AWSClient, logger: Logger, from key: S3StoreKey, to path: String) async throws {
        let s3 = S3(client: client, region: .useast2)
        let s3FileTransfer = S3FileTransferManager(s3: s3, threadPoolProvider: .createNew)

        guard let file = S3File(key: key) else {
            throw Error(message: "Invalid key: \(key)")
        }
        try await s3FileTransfer.copy(from: file, to: path)
    }

    func sync(client: AWSClient, logger: Logger, from folder: String, to key: S3StoreKey) async throws {
        let s3 = S3(client: client,
                    region: .useast2,
                    timeout: .seconds(60),
                    options: .s3DisableChunkedUploads)
        let s3FileTransfer = S3FileTransferManager(s3: s3,
                                                   threadPoolProvider: .createNew,
                                                   configuration: .init(maxConcurrentTasks: 12))

        guard let s3Folder = S3Folder(url: key.url) else {
            throw Error(message: "Invalid key: \(key)")
        }

        var nextProgressTick = 0.1
        try await s3FileTransfer.sync(from: folder, to: s3Folder, delete: true) { progress in
            if progress >= nextProgressTick {
                logger.info("Syncing... [\(percent: progress)]")
                nextProgressTick += 0.1
            }
        }
    }
}


extension S3File {
    init?(key: S3StoreKey) {
        self.init(url: key.url)
    }
}


private extension DefaultStringInterpolation {
    mutating func appendInterpolation(percent value: Double) {
        appendInterpolation(String(format: "%.0f%%", value * 100))
    }
}
