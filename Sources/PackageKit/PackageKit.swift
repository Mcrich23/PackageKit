// The Swift Programming Language
// https://docs.swift.org/swift-book
import Foundation

struct PackageState: Codable {
    let branch: String?
    let version: String?
    let revision: String
}

struct RawPackage: Codable {
    let identity: String
    let kind: String
    let location: String
    let state: PackageState
}

struct PackageDecoder: Codable {
    let pins: [RawPackage]
}

public struct Package {
    let name: String
    let location: String
    let licenseUrl: URL?
}

public struct PackageKit {
    /**
    Get packages from your `Package.resolved` file.

    - parameter from: An optional parameter to specify the path of `Package.resolved`.
    - returns: [Package]
     
    */
    public static func getPackages() -> [Package] {
        let rawPackages = fetchRawPackages()
        
        let packages: [Package] = rawPackages.compactMap { package in
            var licenseUrl: URL? {
                let state = package.state
                let baseUrlString = package.location.replacingOccurrences(of: ".git", with: "").replacingOccurrences(of: "github.com/", with: "raw.githubusercontent.com/")
                if let branch = state.branch {
                    let branchUrlString = "\(baseUrlString)/\(branch)"
                    
                    return self.licenseUrl(for: branchUrlString)
                } else if let version = state.version {
                    let versionUrlString = "\(baseUrlString)/\(version)"
                    
                    return self.licenseUrl(for: versionUrlString)
                } else {
                    return nil
                }
            }
            
            return Package(name: package.identity.capitalized, location: package.location, licenseUrl: licenseUrl)
        }
        return packages
    }
    
    /**
    Gets the license url for a package.

    - parameter for: The url to get the license url from.
    - returns: URL
     
    */
    static func licenseUrl(for url: URL) -> URL? {
        if let licenseUrl = URL(string: "\(url)/LICENSE"), licenseUrl.remoteFileExists() {
            return licenseUrl
        } else if let licenseUrl = URL(string: "\(url)/LICENSE.md"), licenseUrl.remoteFileExists() {
            return licenseUrl
        } else if let licenseUrl = URL(string: "\(url)/LICENSE.txt"), licenseUrl.remoteFileExists() {
            return licenseUrl
        } else {
            return nil
        }
    }
    
    /**
    Gets the license url for a package.

    - parameter for: The url string to get the license url from.
    - returns: URL
     
    */
    static func licenseUrl(for url: String) -> URL? {
        guard let url = URL(string: url) else { return nil}
        
        return licenseUrl(for: url)
    }
    
    /**
    Gets the raw package data from `Package.resolved`

    - parameter from: An optional parameter to specify the path of `Package.resolved`.
    - returns: [RawPackage]
     
    */
    static func fetchRawPackages(from path: String? = Bundle.main.path(forResource: "Package", ofType: "resolved")) -> [RawPackage] {
        if let path  {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
                // Parse the JSON data here using JSONDecoder
                let decoder = JSONDecoder()
//                print(String(data: data, encoding: .utf8) ?? "")
                let packages = try decoder.decode(PackageDecoder.self, from: data)
                // Use jsonData as your parsed JSON object
                
                return packages.pins
            } catch {
                // Handle error while reading or parsing JSON
                print("Error: \(error)")
                return []
            }
        } else {
            // File not found in the main bundle
            print("JSON file not found in the main bundle.")
            return []
        }

    }
}

extension URL {
    /**
     Checks if the remote file on a server exists.
     
     - returns: Bool
     */
    func remoteFileExists() -> Bool {
        var exists = false
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var request = URLRequest(url: self)
        request.httpMethod = "HEAD"
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let httpStatus = (response as? HTTPURLResponse)?.statusCode {
                // HTTP status code 200 means the file exists, 404 means not found
                exists = (httpStatus == 200)
            }
            semaphore.signal()
        }
        task.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        return exists
    }
}
