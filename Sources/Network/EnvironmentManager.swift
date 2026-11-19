//
//  EnvironmentManager.swift
//  MadridInGameModule
//
//  Created by Arnau Rivas Rivas on 7/1/25.
//

import Foundation

public class EnvironmentManager {
    // MARK: - Enumeración de Entornos
    public enum EnvironmentConfig {
        case pre
        case pro
        
        // Inicializador con Booleano
        public init?(isPro: Bool) {
            self = isPro ? .pro : .pre
        }
        
        /// Web origin. Also the value of the `Origin` header required on mutations.
        public var origin: String {
            switch self {
            case .pre:
                return "https://premig.randomkesports.com"
            case .pro:
                return "https://webesports.madridingame.es"
            }
        }

        /// Base of the web data gateway: append `/items/...`, `/assets/<id>`, `/files` or
        /// `/flows/trigger/<id>`. Direct Directus access (`/cms`) is closed since 2026-09.
        public func getBaseURL() -> String {
            "\(origin)/api/data"
        }

        /// `POST|GET|DELETE` of the member session.
        public var sessionURL: String {
            "\(origin)/api/member/session/"
        }
        
        // Método para obtener el nombre del entorno (PRE / PRO)
        public func getEnvironmentName() -> String {
            switch self {
            case .pre:
                return "PRE"
            case .pro:
                return "PRO"
            }
        }
    }
    
    // MARK: - Claves de UserDefaults
    private static let environmentKey = "selectedEnvironment"
    
    // MARK: - Propiedades
    public let currentEnvironment: EnvironmentConfig
    
    // MARK: - Inicializador
    public init(isPro: Bool? = nil) {
        if let isPro = isPro {
            self.currentEnvironment = EnvironmentConfig(isPro: isPro)!
            EnvironmentManager.saveEnvironment(isPro)
        } else if let savedEnv = EnvironmentManager.loadEnvironment() {
            self.currentEnvironment = EnvironmentConfig(isPro: savedEnv) ?? .pro
        } else {
            self.currentEnvironment = .pro
            EnvironmentManager.saveEnvironment(true)
        }
    }
    
    // MARK: - Métodos Públicos
    public func getBaseURL() -> String {
        return currentEnvironment.getBaseURL()
    }
    
    public func getEnvironmentName() -> String {
        return currentEnvironment.getEnvironmentName()
    }

    public func getOrigin() -> String {
        return currentEnvironment.origin
    }
    
    // MARK: - Métodos Privados (Almacenamiento en UserDefaults)
    private static func saveEnvironment(_ isPro: Bool) {
        UserDefaults.standard.set(isPro, forKey: environmentKey)
    }
    
    private static func loadEnvironment() -> Bool? {
        return UserDefaults.standard.value(forKey: environmentKey) as? Bool
    }
}

/// Environment selected at module launch. Set once by the module, read by the HTTP client.
enum MIGEnvironment {
    private static let lock = NSLock()
    private static var configured: EnvironmentManager.EnvironmentConfig = .pro

    static var current: EnvironmentManager.EnvironmentConfig {
        get { lock.lock(); defer { lock.unlock() }; return configured }
        set { lock.lock(); configured = newValue; lock.unlock() }
    }
}

//public class EnvironmentManager {
//    // MARK: - Enumeración de Entornos
//    public enum EnvironmentConfig: String {
//        case pre = "https://premig.randomkesports.com/cms"
//        case pro = "https://webesports.madridingame.es/cms"
//        
//        public init?(environment: String) {
//            switch environment.lowercased() {
//            case "pre":
//                self = .pre
//            case "pro":
//                self = .pro
//            default:
//                return nil
//            }
//        }
//        
//        // Método para obtener el nombre del environment (PRE / PRO)
//        public func getEnvironmentName() -> String {
//            switch self {
//            case .pre:
//                return "PRE"
//            case .pro:
//                return "PRO"
//            }
//        }
//    }
//    
//    // MARK: - Claves de UserDefaults
//    private static let environmentKey = "selectedEnvironment"
//    
//    // MARK: - Propiedades
//    public let currentEnvironment: EnvironmentConfig
//    
//    // MARK: - Inicializador
//    public init(environment: String? = nil) {
//        if let env = environment, let config = EnvironmentConfig(environment: env) {
//            self.currentEnvironment = config
//            EnvironmentManager.saveEnvironment(env)
//        } else if let savedEnv = EnvironmentManager.loadEnvironment(),
//                  let config = EnvironmentConfig(environment: savedEnv) {
//            self.currentEnvironment = config
//        } else {
//            self.currentEnvironment = .pro
//            EnvironmentManager.saveEnvironment("pro")
//        }
//    }
//    
//    // MARK: - Métodos Públicos
//    public func getBaseURL() -> String {
//        return currentEnvironment.rawValue
//    }
//    
//    public func getEnvironmentName() -> String {
//        return currentEnvironment.getEnvironmentName()
//    }
//    
//    // MARK: - Métodos Privados (Almacenamiento en UserDefaults)
//    private static func saveEnvironment(_ environment: String) {
//        UserDefaults.standard.set(environment, forKey: environmentKey)
//    }
//    
//    private static func loadEnvironment() -> String? {
//        return UserDefaults.standard.string(forKey: environmentKey)
//    }
//}

//public class EnvironmentManager {
//    // MARK: - Enumeración de Entornos
//    public enum EnvironmentConfig: String {
//        case pre = "https://premig.randomkesports.com/cms"
//        case pro = "https://webesports.madridingame.es/cms"
//        
//        public init?(environment: String) {
//            switch environment.lowercased() {
//            case "pre":
//                self = .pre
//            case "pro":
//                self = .pro
//            default:
//                return nil
//            }
//        }
//    }
//    
//    // MARK: - Propiedades
//    public let currentEnvironment: EnvironmentConfig
//    
//    // Inicializador
//    public init(environment: String) {
//        if let config = EnvironmentConfig(environment: environment) {
//            self.currentEnvironment = config
//        } else {
//            self.currentEnvironment = .pro
//        }
//    }
//    
//    // MARK: - Métodos Públicos
//    public func getBaseURL() -> String {
//        return currentEnvironment.rawValue
//    }
//}

