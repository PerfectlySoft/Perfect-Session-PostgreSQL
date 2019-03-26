// swift-tools-version:4.2
// Generated automatically by Perfect Assistant Application
// Date: 2017-01-12 20:41:34 +0000
import PackageDescription
let package = Package(
    name: "PerfectSessionPostgreSQL",
	products: [
		.library(name: "PerfectSessionPostgreSQL", targets: ["PerfectSessionPostgreSQL"])
	],
    dependencies: [
		.package(url: "https://github.com/PerfectlySoft/Perfect-Session.git", from: "3.0.0"),
		.package(url: "https://github.com/PerfectlySoft/Perfect-PostgreSQL.git", from: "3.0.0"),
    ],
	targets: [
		.target(name: "PerfectSessionPostgreSQL", dependencies: ["PerfectSession", "PerfectPostgreSQL"])
	]
)
