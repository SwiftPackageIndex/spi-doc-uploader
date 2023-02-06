// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

@testable import DocUploadBundle
@testable import DocUploader

import AsyncHTTPClient
import Dependencies


final class DocUploadTests: XCTestCase {

    func test_init() throws {
        let cafe = UUID(uuidString: "cafecafe-cafe-cafe-cafe-cafecafecafe")!
        let bundle = withDependencies {
            $0.uuid = .constant(cafe)
        } operation: {
            DocUploadBundle(sourcePath: "/foo/bar/owner/name/branch",
                            bucket: "spi-prod-docs",
                            repository: .init(owner: "Owner", name: "Name"),
                            reference: "Branch",
                            apiBaseURL: "baseURL",
                            apiToken: "token",
                            buildId: cafe,
                            fileCount: 123,
                            mbSize: 456)
        }
        XCTAssertEqual(bundle.archiveName, "prod-owner-name-branch-cafecafe.zip")
        XCTAssertEqual(bundle.metadata,
                       .init(
                           apiBaseURL: "baseURL",
                           apiToken: "token",
                           buildId: cafe,
                           fileCount: 123,
                           mbSize: 456,
                           sourcePath: "branch",
                           targetFolder: bundle.s3Folder)
                       )
        XCTAssertEqual(bundle.s3Folder,
                       .init(bucket: "spi-prod-docs", path: "owner/name/branch"))
    }

    func test_logUrl() throws {
        let logURL = DocUploader
            .logURL(region: "us-east-2",
                    logGroup: "/aws/lambda/DocUploaderLambda-Test-UploadFunction-3D3w0QTh1l6H",
                    logStream: "2023/01/30/[$LATEST]3ecb4050574245699b3db785b07142f2")

        XCTAssertEqual(logURL,
                       "https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#logsV2:log-groups/log-group/$252Faws$252Flambda$252FDocUploaderLambda-Test-UploadFunction-3D3w0QTh1l6H/log-events/2023$252F01$252F30$252F$255B$2524LATEST$255D3ecb4050574245699b3db785b07142f2")
    }

    func test_reportResult() async throws {
        var request: HTTPClientRequest?
        try await withDependencies {
            $0.httpClient.execute = { _, req, _ in
                request = req
                return .init(status: .noContent)
            }
        } operation: {
            let client = HTTPClient(eventLoopGroupProvider: .createNew)
            defer { try? client.syncShutdown() }
            let status = try await DocReport.reportResult(
                client: client,
                apiBaseURL: "http://localhost:8080/api",
                apiToken: "builder-token",
                buildId: UUID(uuidString: "f6ab0ddb-2540-4613-b087-ed55474f6b16")!,
                dto: .init(error: "too big",
                           fileCount: 1_234,
                           logUrl: "log url 1",
                           mbSize: 123,
                           status: .skipped))
            XCTAssertEqual(status, .noContent)
        }
        XCTAssertEqual(
            request?.url,
            "http://localhost:8080/api/builds/F6AB0DDB-2540-4613-B087-ED55474F6B16/doc-report"
        )
        XCTAssertEqual(
            request?.headers.first(name: "Authorization"),
            "Bearer builder-token"
        )
        XCTAssertEqual(
            request?.headers.first(name: "Content-Type"),
            "application/json"
        )
    }

}
