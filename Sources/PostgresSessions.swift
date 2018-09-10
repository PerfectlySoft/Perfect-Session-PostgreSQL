//
//  PostgresSessions.swift
//  Perfect-Session-PostgreSQL
//
//  Created by Jonathan Guthrie on 2016-12-19.
//
//

import PerfectLib
import PerfectPostgreSQL
import PerfectSession
import PerfectHTTP
import Foundation

public struct PostgresSessionConnector {

	public static var host: String		= "localhost"
	public static var username: String	= ""
	public static var password: String	= ""
	public static var database: String	= "perfect_sessions"
	public static var table: String		= "sessions"
	public static var port: Int			= 5432

	private init(){}

	public static func connectionString() -> String {
		return "postgresql://\(PostgresSessionConnector.username.stringByEncodingURL):\(PostgresSessionConnector.password.stringByEncodingURL)@\(PostgresSessionConnector.host.stringByEncodingURL):\(PostgresSessionConnector.port)/\(PostgresSessionConnector.database.stringByEncodingURL)"
	}

}


public struct PostgresSessions {

	/// Initializes the Session Manager. No config needed!
	public init() {
		setup()
	}

	public func clean() {
		let stmt = "DELETE FROM \(PostgresSessionConnector.table) WHERE updated + idle < $1"
		exec(stmt, params: [Int(Date().timeIntervalSince1970)])
	}

	public func save(session: PerfectSession) {
		var s = session
		s.updated = Int(Date().timeIntervalSince1970)
		// perform UPDATE
		let stmt = "UPDATE \(PostgresSessionConnector.table) SET userid = $1, updated = $2, idle = $3, data = $4 WHERE token = $5"
		exec(stmt, params: [
			s.userid,
			s.updated,
			s.idle,
			s.tojson(),
			s.token
			])
	}

	public func start(_ request: HTTPRequest) -> PerfectSession {
		var session = PerfectSession()
		session.token = UUID().uuidString
		session.idle = SessionConfig.idle

		// adding for x-forwarded-for support:
		let ff = request.header(.xForwardedFor) ?? ""
		if ff.isEmpty {
			// session setting normally (not load balanced)
			session.ipaddress = request.remoteAddress.host
		} else {
			// Session is coming through a load balancer or proxy
			session.ipaddress = ff
		}

		session.useragent = request.header(.userAgent) ?? "unknown"
		session._state = "new"
		session.setCSRF()

		// perform INSERT
		let stmt = "INSERT INTO \(PostgresSessionConnector.table) (token,userid,created, updated, idle, data, ipaddress, useragent) VALUES($1,$2,$3,$4,$5,$6,$7,$8)"
		exec(stmt, params: [
			session.token,
			session.userid,
			session.created,
			session.updated,
			session.idle,
			session.tojson(),
			session.ipaddress,
			session.useragent
			])
		return session
	}

	/// Deletes the session for a session identifier.
	public func destroy(_ request: HTTPRequest, _ response: HTTPResponse) {
		let stmt = "DELETE FROM \(PostgresSessionConnector.table) WHERE token = $1"
		if let t = request.session?.token {
			exec(stmt, params: [t])
		}

		// Reset cookie to make absolutely sure it does not get recreated in some circumstances.
		var domain = ""
		if !SessionConfig.cookieDomain.isEmpty {
			domain = SessionConfig.cookieDomain
		}
		response.addCookie(HTTPCookie(
			name: SessionConfig.name,
			value: "",
			domain: domain,
			expires: .relativeSeconds(SessionConfig.idle),
			path: SessionConfig.cookiePath,
			secure: SessionConfig.cookieSecure,
			httpOnly: SessionConfig.cookieHTTPOnly,
			sameSite: SessionConfig.cookieSameSite
			)
		)

	}

	public func resume(token: String) -> PerfectSession {
		var session = PerfectSession()
		let server = connect()
		let result = server.exec(statement: "SELECT token,userid,created, updated, idle, data, ipaddress, useragent FROM \(PostgresSessionConnector.table) WHERE token = $1", params: [token])

		let num = result.numTuples()
		for x in 0..<num {
			session.token = result.getFieldString(tupleIndex: x, fieldIndex: 0) ?? ""
			session.userid = result.getFieldString(tupleIndex: x, fieldIndex: 1) ?? ""
			session.created = result.getFieldInt(tupleIndex: x, fieldIndex: 2) ?? 0
			session.updated = result.getFieldInt(tupleIndex: x, fieldIndex: 3) ?? 0
			session.idle = result.getFieldInt(tupleIndex: x, fieldIndex: 4) ?? 0
			if let str = result.getFieldString(tupleIndex: x, fieldIndex: 5) {
				session.fromjson(str)
			}
			session.ipaddress = result.getFieldString(tupleIndex: x, fieldIndex: 6) ?? ""
			session.useragent = result.getFieldString(tupleIndex: x, fieldIndex: 7) ?? ""
		}
		result.clear()

		server.close()
		session._state = "resume"
		return session
	}


	// Postgres Specific:
	func connect() -> PGConnection {
		let server = PGConnection()
		let status = server.connectdb(PostgresSessionConnector.connectionString())
		if status != .ok {
			Log.error(message:
				"Unable to connect to the session database. " +
				"connectionString: \(PostgresSessionConnector.connectionString()), " +
				"status: \(status)")
		}
		return server
	}

	func setup(){
		let stmt = "CREATE TABLE \"\(PostgresSessionConnector.table)\" (\"token\" varchar NOT NULL, \"userid\" varchar, \"created\" int4 NOT NULL DEFAULT 0, \"updated\" int4 NOT NULL DEFAULT 0, \"idle\" int4 NOT NULL DEFAULT 0, \"data\" text, \"ipaddress\" varchar, \"useragent\" text, PRIMARY KEY (\"token\") NOT DEFERRABLE INITIALLY IMMEDIATE ) WITH (OIDS=FALSE);"
		exec(stmt, params: [])
	}

	func exec(_ statement: String, params: [Any]) {
		let server = connect()
		let _ = server.exec(statement: statement, params: params)
		server.close()
	}

	func isError(_ errorMsg: String) -> Bool {
		if errorMsg.contains(string: "ERROR") {
			print(errorMsg)
			return true
		}
		return false
	}

}
