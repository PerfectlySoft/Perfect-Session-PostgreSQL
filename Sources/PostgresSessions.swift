//
//  PostgresSessions.swift
//  Perfect-Session-PostgreSQL
//
//  Created by Jonathan Guthrie on 2016-12-19.
//
//

import TurnstileCrypto
import PostgreSQL
import PerfectSession

public struct PostgresSessionConnector {

	public static var host: String		= "localhost"
	public static var username: String	= ""
	public static var password: String	= ""
	public static var database: String	= "perfect_sessions"
	public static var table: String		= "sessions"
	public static var port: Int			= 5432

	private init(){}

	public static func connectionString() -> String {
		return "postgresql://\(PostgresSessionConnector.username):\(PostgresSessionConnector.password)@\(PostgresSessionConnector.host):\(PostgresSessionConnector.port)/\(PostgresSessionConnector.database)"
	}

}


public struct PostgresSessions {

	/// Initializes the Session Manager. No config needed!
	public init() {}


	public func save(session: PerfectSession) {
		var s = session
		s.touch()
		// perform UPDATE
		let stmt = "UPDATE \(PostgresSessionConnector.table) SET userid = $1, updated = $1, idle = $3, data = $4 WHERE token = $5"
		exec(stmt, params: [
			session.userid,
			session.updated,
			session.idle,
			session.tojson(),
			session.token
			])
	}

	public func start() -> PerfectSession {
		let rand = URandom()
		var session = PerfectSession()
		session.token = rand.secureToken

		// perform INSERT
		let stmt = "INSERT INTO \(PostgresSessionConnector.table) (token,userid,created, updated, idle, data) VALUES($1,$2,$3,$4,$5,$6)"
		exec(stmt, params: [
			session.token,
			session.userid,
			session.created,
			session.updated,
			session.idle,
			session.tojson()
			])
		return session
	}

	/// Deletes the session for a session identifier.
	public func destroy(token: String) {
		let stmt = "DELETE FROM \(PostgresSessionConnector.table) WHERE token = $1"
		exec(stmt, params: [token])
	}

	public func resume(token: String) -> PerfectSession {
		var session = PerfectSession()
		let server = connect()
		let result = server.exec(statement: "SELECT token,userid,created, updated, idle, data FROM \(PostgresSessionConnector.table) WHERE token = $1", params: [token])
//		let errorMsg = server.errorMessage().trimmingCharacters(in: .whitespacesAndNewlines)
//		print(errorMsg)

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
		}
		result.clear()

		server.close()
		return session
	}


	// Postgres Specific:
	func connect() -> PGConnection {
		let server = PGConnection()
		let status = server.connectdb(PostgresSessionConnector.connectionString())
		if status != .ok {
			print("\(status)")
		}
		return server
	}

	func setup(){
		let stmt = "CREATE TABLE \"\(PostgresSessionConnector.table)\" (\"token\" varchar NOT NULL, \"userid\" varchar, \"created\" int4 NOT NULL DEFAULT 0, \"updated\" int4 NOT NULL DEFAULT 0, \"idle\" int4 NOT NULL DEFAULT 0, \"data\" text, PRIMARY KEY (\"token\") NOT DEFERRABLE INITIALLY IMMEDIATE ) WITH (OIDS=FALSE);"
		exec(stmt, params: [])
	}

	func exec(_ statement: String, params: [Any]) {
		let server = connect()
		let _ = server.exec(statement: statement, params: params)
//		let errorMsg = server.errorMessage().trimmingCharacters(in: .whitespacesAndNewlines)
//		print(errorMsg)
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



