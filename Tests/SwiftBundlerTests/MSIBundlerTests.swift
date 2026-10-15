import Foundation
import Testing

#if canImport(FoundationXML)
  import FoundationXML
#endif

@testable import SwiftBundler

struct MSIBundlerTests {
  @Test(.bug("https://github.com/moreSwift/swift-bundler/issues/210"))
  func testExtensionNamespaceGeneration() async throws {
    let xml = try await generateWXS(configuration: """
      msi.wix_extensions = ["WixToolset.Util.wixext/6.0.0"]
      msi.wxs_namespaces.util = "http://wixtoolset.org/schemas/v4/wxs/util"
      msi.wxs_extras = [
        {
          tag = "util:CloseApplication",
          Id = "CloseApp",
          Target = "HelloWorld.exe",
          CloseMessage = "yes",
        }
      ]
      """)

    #expect(xml.contains("xmlns=\"http://wixtoolset.org/schemas/v4/wxs\""))
    #expect(xml.contains("xmlns:util=\"http://wixtoolset.org/schemas/v4/wxs/util\""))
    #expect(xml.contains("<util:CloseApplication "))

    let parser = XMLParser(data: Data(xml.utf8))
    let delegate = NamespaceParserDelegate()
    parser.shouldProcessNamespaces = true
    parser.delegate = delegate
    #expect(parser.parse(), "\(String(describing: parser.parserError))")
    #expect(delegate.namespaces["Wix"] == "http://wixtoolset.org/schemas/v4/wxs")
    #expect(delegate.namespaces["Package"] == "http://wixtoolset.org/schemas/v4/wxs")
    #expect(
      delegate.namespaces["CloseApplication"] == "http://wixtoolset.org/schemas/v4/wxs/util"
    )
  }

  @Test(arguments: ["", "msi.wxs_namespaces = {}"])
  func testDefaultNamespaceGeneration(configuration: String) async throws {
    let xml = try await generateWXS(configuration: configuration)
    #expect(xml.contains("<Wix xmlns=\"http://wixtoolset.org/schemas/v4/wxs\">"))
    #expect(!xml.contains("xmlns:"))
  }

  @Test func testNamespaceOrderingAndEscaping() async throws {
    let xml = try await generateWXS(configuration: """
      msi.wxs_namespaces.z = "urn:example:z"
      msi.wxs_namespaces.a = "https://example.com/extension?one=1&two=2"
      """)
    #expect(xml.contains("""
      <Wix xmlns="http://wixtoolset.org/schemas/v4/wxs" xmlns:a="https://example.com/extension?one=1&amp;two=2" xmlns:z="urn:example:z">
      """))

    let reversed = try await generateWXS(configuration: """
      msi.wxs_namespaces.a = "https://example.com/extension?one=1&two=2"
      msi.wxs_namespaces.z = "urn:example:z"
      """)
    let rootTag = try #require(xml.range(of: #"<Wix\b[^>]*>"#, options: .regularExpression))
    let reversedRootTag = try #require(
      reversed.range(of: #"<Wix\b[^>]*>"#, options: .regularExpression)
    )
    #expect(xml[rootTag] == reversed[reversedRootTag])
  }

  /// Exercises WXS generation without building an app or invoking WiX.
  private func generateWXS(configuration: String) async throws -> String {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-bundler-msi-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let configuration = try await PackageConfigurationTests.flattenTOMLConfiguration(
      """
      format_version = 2

      [apps.HelloWorld]
      product = "HelloWorld"
      identifier = "com.example.HelloWorld"
      version = "0.1.0"
      \(configuration)
      """,
      packageDirectory: directory,
      with: ConfigurationFlattener.Context(
        platform: .windows,
        bundler: .windowsMSI,
        architectures: [.x86_64]
      )
    )
    let app = try #require(configuration.apps["HelloWorld"])
    let bundle = GenericWindowsBundler.BundleStructure(
      at: directory,
      forApp: "HelloWorld",
      withIdentifier: app.identifier
    )
    try Data().write(to: bundle.mainExecutable)

    let context = BundlerContext(
      appName: "HelloWorld",
      packageName: "HelloWorld",
      configuration: configuration,
      appConfiguration: app,
      packageDirectory: directory,
      productsDirectory: directory,
      outputDirectory: directory,
      packageGraph: SwiftPackageManager.PackageGraph(
        rootPackage: SwiftPackageManager.Package(
          name: "HelloWorld",
          identity: "helloworld",
          source: .local(path: directory),
          localCheckout: directory,
          dependencies: [],
          traits: [],
          products: [:],
          targets: [:],
          fullConfiguration: nil,
          configuration: configuration
        ),
        dependencyPackages: [:],
        ignoredTransitiveDependencies: [],
        enabledTraits: [:]
      ),
      architectures: [.x86_64],
      buildConfiguration: .debug,
      platform: .windows,
      platformVersion: nil,
      device: nil,
      darwinCodeSigningContext: nil,
      windowsCodeSigningContext: nil,
      builtDependencies: [:],
      mainArtifact: bundle.mainExecutable,
      swiftToolchain: nil,
      swiftSDK: nil
    )
    let data = try MSIBundler.generateWXSFileContents(
      genericBundle: bundle,
      appName: "HelloWorld",
      appConfiguration: app,
      context: context
    )
    return try #require(String(data: data, encoding: .utf8))
  }

  private final class NamespaceParserDelegate: NSObject, XMLParserDelegate {
    var namespaces: [String: String] = [:]

    func parser(
      _ parser: XMLParser,
      didStartElement elementName: String,
      namespaceURI: String?,
      qualifiedName: String?,
      attributes: [String: String]
    ) {
      namespaces[elementName] = namespaceURI
    }
  }
}
