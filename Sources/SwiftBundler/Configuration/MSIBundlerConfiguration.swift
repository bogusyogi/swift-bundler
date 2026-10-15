import Foundation
import XMLCoder
import Version

/// MSI bundler related configuration properties.
@Configuration(overlayable: false)
struct MSIBundlerConfiguration: Codable, Hashable, Sendable {
  /// Additional entries to add to the app's WXS configuration file before
  /// invoking the WiX CLI to produce the final MSI.
  ///
  /// For example, here's how you could set your app to auto-launch using
  /// custom WiX actions.
  ///
  /// ```toml
  /// msi.wxs_extras = [
  ///   {
  ///     tag = "CustomAction",
  ///     Id = "LaunchApplication",
  ///     Execute = "immediate",
  ///     Impersonate = "no",
  ///     Return = "asyncNoWait",
  ///     Directory = "InstallFolder",
  ///     ExeCommand = "[#MainExecutable]",
  ///   },
  ///   {
  ///     tag = "InstallExecuteSequence",
  ///     children = [
  ///       {
  ///         tag = "Custom",
  ///         Action = "LaunchApplication",
  ///         After = "InstallFinalize",
  ///       }
  ///     ]
  ///   },
  /// ]
  /// ```
  var wxsExtras: [WXSValue]?

  /// XML namespace prefixes and their URIs to register on the WXS root element.
  /// Use these prefixes in ``wxsExtras`` to refer to elements from WiX extensions.
  ///
  /// ```toml
  /// msi.wxs_namespaces.util = "http://wixtoolset.org/schemas/v4/wxs/util"
  /// ```
  var wxsNamespaces: [String: String]?

  /// WiX extensions required to build an MSI installer of the app.
  var wixExtensions: [WiXTool.ExtensionSpecifier]?
}
