import Foundation

// `ssfm` — command line front end. Builds an `ssfm://` URL and hands it to the app
// via `/usr/bin/open -g` (keeps the current app in front). Foundation only.

let arguments = Array(CommandLine.arguments.dropFirst())
let outcome = CLIParser.parse(arguments)

switch outcome {
case .help:
    print(CLIUsage.text)
    exit(CLIExit.success)
case .version:
    print("ssfm \(CLIUsage.version)")
    exit(CLIExit.success)
case let .failure(message):
    FileHandle.standardError.write(Data("ssfm: \(message)\nRun 'ssfm --help' for usage.\n".utf8))
    exit(CLIExit.usage)
case let .url(url):
    exit(URLLauncher.open(url))
}
