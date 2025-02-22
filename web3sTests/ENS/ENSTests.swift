//
//  web3.swift
//  Copyright © 2022 Argent Labs Limited. All rights reserved.
//

import XCTest
@testable import web3

class ENSTests: XCTestCase {
    var account: EthereumAccount?
    var client: EthereumClientProtocol!

    override func setUp() {
        super.setUp()
        client = EthereumHttpClient(url: URL(string: TestConfig.clientUrl)!)
    }

    func testGivenName_ThenResolvesNameHash() {
        let name = "argent.test"
        let nameHash = EthereumNameService.nameHash(name: name)
        XCTAssertEqual(nameHash, "0x3e58ef7a2e196baf0b9d36a65cc590ac9edafb3395b7cdeb8f39206049b4534c")
    }

    func testGivenRopstenRegistry_WhenExistingDomainName_ResolvesOwnerAddressCorrectly() async {
        do {
            let function = ENSContracts.ENSRegistryFunctions.owner(contract: ENSContracts.RegistryAddress, _node: EthereumNameService.nameHash(name: "test").web3.hexData ?? Data())

            let tx = try function.transaction()

            let dataStr = try await client?.eth_call(tx, resolution: .noOffchain(failOnExecutionError: true), block: .Latest)
            guard let dataStr = dataStr else {
                XCTFail()
                return
            }

            let owner = String(dataStr[dataStr.index(dataStr.endIndex, offsetBy: -40)...])
            XCTAssertEqual(owner.web3.noHexPrefix, "09b5bd82f3351a4c8437fc6d7772a9e6cd5d25a1")
        } catch {
            XCTFail("Expected dataStr but failed \(error).")
        }
    }

    func testGivenRopstenRegistry_WhenExistingAddress_ThenResolvesCorrectly() async {
        do {
            let nameService = EthereumNameService(client: client!)
            let ens = try await nameService.resolve(
                address: "0xb0b874220ff95d62a676f58d186c832b3e6529c8",
                mode: .onchain
            )
            XCTAssertEqual("julien.argent.test", ens)
        } catch {
            XCTFail("Expected ens but failed \(error).")
        }
    }

    func testGivenRopstenRegistry_WhenNotExistingAddress_ThenFailsCorrectly() async {
        do {
            let nameService = EthereumNameService(client: client!)
            _ = try await nameService.resolve(
                address: "0xb0b874220ff95d62a676f58d186c832b3e6529c9",
                mode: .onchain
            )
            XCTFail("Expected to throw while awaiting, but succeeded")
        } catch {
            XCTAssertEqual(error as? EthereumNameServiceError, .ensUnknown)
        }
    }

    func testGivenCustomRegistry_WhenNotExistingAddress_ThenResolvesFailsCorrectly() async {
        do {
            let nameService = EthereumNameService(client: client!, registryAddress: "0x7D7C04B7A05539a92541105806e0971E45969F85")
            _ = try await nameService.resolve(
                address: "0xb0b874220ff95d62a676f58d186c832b3e6529c9",
                mode: .onchain
            )
            XCTFail("Expected to throw while awaiting, but succeeded")
        } catch {
            XCTAssertEqual(error as? EthereumNameServiceError, .ensUnknown)
        }
    }

    func testGivenRopstenRegistry_WhenExistingENS_ThenResolvesAddressCorrectly() async {
        do {
            let nameService = EthereumNameService(client: client!)
            let ens = try await nameService.resolve(
                ens: "julien.argent.test",
                mode: .onchain
            )
            XCTAssertEqual(EthereumAddress("0xb0b874220ff95d62a676f58d186c832b3e6529c8"), ens)
        } catch {
            XCTFail("Expected ens but failed \(error).")
        }
    }

    func testGivenRopstenRegistry_WhenInvalidENS_ThenErrorsRequest() async {
        do {
            let nameService = EthereumNameService(client: client!)
            _ = try await nameService.resolve(
                ens: "**somegarbage)_!!",
                mode: .onchain
            )
            XCTFail("Expected to throw while awaiting, but succeeded")
        } catch {
            XCTAssertEqual(error as? EthereumNameServiceError, .ensUnknown)
        }
    }

    func testGivenCustomRegistry_WhenInvalidENS_ThenErrorsRequest() async {
        do {
            let nameService = EthereumNameService(client: client!, registryAddress: "0x7D7C04B7A05539a92541105806e0971E45969F85")
            _ = try await nameService.resolve(
                ens: "**somegarbage)_!!",
                mode: .onchain
            )
            XCTFail("Expected to throw while awaiting, but succeeded")
        } catch {
            XCTAssertEqual(error as? EthereumNameServiceError, .ensUnknown)
        }
    }

    func testGivenRopstenRegistry_ThenResolvesMultipleAddressesInOneCall() async {
        do {
            let nameService = EthereumNameService(client: client!)

            var results: [EthereumNameService.ResolveOutput<String>]?

            let resolutions = try await nameService.resolve(addresses: [
                "0xb0b874220ff95d62a676f58d186c832b3e6529c8",
                "0x09b5bd82f3351a4c8437fc6d7772a9e6cd5d25a1",
                "0x7e691d7ffb007abe91d8a24d7f22fc74307dab06"
            ])

            results = resolutions.map { $0.output }

            XCTAssertEqual(
                results,
                [
                    .resolved("julien.argent.test"),
                    .couldNotBeResolved(.ensUnknown),
                    .resolved("davidtests.argent.xyz")
                ]
            ) } catch {
                XCTFail("Expected resolutions but failed \(error).")
            }
    }

    func testGivenRopstenRegistry_ThenResolvesMultipleNamesInOneCall() async {
        do {
            let nameService = EthereumNameService(client: client!)

            var results: [EthereumNameService.ResolveOutput<EthereumAddress>]?

            let resolutions = try await nameService.resolve(names: [
                "julien.argent.test",
                "davidtests.argent.xyz",
                "somefakeens.argent.xyz"
            ])

            results = resolutions.map { $0.output }

            XCTAssertEqual(
                results,
                [
                    .resolved("0xb0b874220ff95d62a676f58d186c832b3e6529c8"),
                    .resolved("0x7e691d7ffb007abe91d8a24d7f22fc74307dab06"),
                    .couldNotBeResolved(.ensUnknown)
                ]
            )
        } catch {
            XCTFail("Expected resolutions but failed \(error).")
        }
    }

    func testGivenRopstenRegistry_WhenWildcardSupported_AndAddressHasSubdomain_ThenResolvesExampleCorrectly() async {
        do {
            let nameService = EthereumNameService(client: client!)

            let address = try await nameService.resolve(
                ens: "ricmoose.hatch.eth",
                mode: .onchain
            )

            XCTAssertEqual(address, EthereumAddress("0x4FaBE0A3a4DDd9968A7b4565184Ad0eFA7BE5411"))
        } catch {
            XCTFail("Expected ens but failed \(error).")
        }
    }

    func testGivenRopstenRegistry_WhenWildcardNOTSupported_AndAddressHasSubdomain_ThenFailsResolving() async {
        do {
            let nameService = EthereumNameService(client: client!)

            _ = try await nameService.resolve(
                ens: "1.resolver.eth",
                mode: .onchain
            )

            XCTFail("Expected error")
        } catch {
            XCTAssertEqual(error as? EthereumNameServiceError, .ensUnknown)
        }
    }
}

class ENSWebSocketTests: ENSTests {
    override func setUp() {
        super.setUp()
        client = EthereumWebSocketClient(url: URL(string: TestConfig.wssUrl)!, configuration: TestConfig.webSocketConfig)
    }
}
