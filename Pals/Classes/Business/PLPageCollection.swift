//
//  PLPageCollection.swift
//  Pals
//
//  Created by ruckef on 07.09.16.
//  Copyright © 2016 citirex. All rights reserved.
//

import AFNetworking

protocol PLPageCollectionDelegate : class {
    func pageCollectionDidLoadPage(objects: [AnyObject])
    func pageCollectionDidChange(indexPaths: [NSIndexPath])
    func pageCollectionDidFail(error: NSError)
}

extension PLPageCollectionDelegate {
    func pageCollectionDidFail(error: NSError) {}
}

typealias PLURLParams = [String:AnyObject]

class PLPageCollectionDeserializer<T:PLUniqueObject>: NSObject {
    private var keyPath = [String]()

    func appendPath(path: [String]) {
        keyPath.appendContentsOf(path)
    }
    
    func deserialize(page: AnyObject) -> ([T],NSError?) {
        var objects: AnyObject?
        for key in keyPath {
            objects = page[key]
            if objects == nil {
                let error = NSError(domain: "PageCollection", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Failed to parse JSON"])
                return ([T](), error)
            }
        }
        let pageDics = objects as! [Dictionary<String,AnyObject>]
        let deserializedObjects = deserializeResponseDic(pageDics)
        return (deserializedObjects, nil)
    }
    
    private func deserializeResponseDic(dic: [Dictionary<String,AnyObject>]) -> [T] {
        var pageObjects = [T]()
        for jsonObject in dic {
            if let object = T(jsonDic: jsonObject) {
                pageObjects.append(object)
            }
        }
        return pageObjects
    }
}

struct PLPageCollectionPreset {
    var id = UInt64(0) // for specific user identifier
    var idKey = "" // for specific user identifier
    let url: String
    let sizeKey: String
    let offsetKey: String
    let size: Int
    let offsetById: Bool // if true starts a next page from lastId+1 otherwise uses a last saved offset
    var params : PLURLParams?
    
    init(url: String, sizeKey: String, offsetKey: String, size: Int, offsetById: Bool) {
        self.url = url
        self.sizeKey = sizeKey
        self.offsetKey = offsetKey
        self.size = size
        self.offsetById = offsetById
    }
    
    subscript(key: String) -> AnyObject? {
        set(newValue) {
            if params == nil {
                params = PLURLParams()
            }
            params![key] = newValue
        }
        get {
            return params?[key]
        }
    }
    
}

class PLPageCollection<T:PLUniqueObject where T : PLFilterable> {
    weak var delegate: PLPageCollectionDelegate?
    var preset: PLPageCollectionPreset
    private var _objects = [T]()
    private var filtered = [T]()
    var objects: [T] {
        return searching ? filtered : _objects
    }
    
    var searching = false
    var session: AFHTTPSessionManager?
    
    private var offset = UInt64(0)
    private var loading = false
    private var deserializer = PLPageCollectionDeserializer<T>()
    
    init(preset: PLPageCollectionPreset) {
        self.preset = preset
    }
    
    var count: Int {
        return objects.count
    }
    var empty: Bool { return objects.count > 0 ? false : true }
    
    var pageSize: Int {
        return preset.size
    }
    
    var pagesLoaded: Int {
        var pages = abs(count/pageSize)
        if count%pageSize > 0 {
            pages += 1
        }
        return pages
    }
    
    subscript(index: Int) -> T {
        return objects[index]
    }
    
    func shouldLoadNextPage(indexPath: NSIndexPath) -> Bool {
        if searching {
            return false
        }
        if indexPath.row == objects.count - 1 {
            return true
        }
        return false
    }
    
    func filter(text: String, completion: ()->()) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            self.filtered.removeAll()
            let newFiltered = self._objects.filter { (object) -> Bool in
                let result = T.filter(object, text: text)
                return result
            }
            self.filtered.appendContentsOf(newFiltered)
            dispatch_async(dispatch_get_main_queue(), {
                completion()
            })
        }
    }
    
    func load() {
        if !loading {
            loadNext({ (objects, error) in
                if error != nil {
                    self.delegate?.pageCollectionDidFail(error!)
                } else {
                    self.delegate?.pageCollectionDidLoadPage(objects)
                    let indices = self.findLastIndices(objects.count)
                    self.delegate?.pageCollectionDidChange(indices)
                }
            })
        }
    }
    
    func findLastIndices(lastCount: Int) -> [NSIndexPath] {
        var indexPaths = [NSIndexPath]()
        if lastCount > 0 {
            for i in count - lastCount..<count {
                indexPaths.append(NSIndexPath(forRow: i, inSection: 0))
            }
        }
        return indexPaths
    }
    
    func deserialize(page: AnyObject) -> ([T],NSError?) {
        return deserializer.deserialize(page)
    }
    
    func appendPath(path: [String]) {
        deserializer.appendPath(path)
    }
    
    typealias PageLoadCompletion = (objects: [T], error: NSError?) -> ()
    let jsonError = NSError(domain: "PageCollection", code: 1001, userInfo: [NSLocalizedDescriptionKey : "Failed to parse JSON"])
    
    private func loadNext(completion: PageLoadCompletion) {
        loading = true
        let params = formParameters(preset, offset: offset)
        if session == nil {
            return
        }
        session!.GET(preset.url, parameters: params, progress: nil, success: { (task, response) in
            self.loading = false
            guard
                let page = response
            else {
                completion(objects:[T](), error: self.jsonError)
                return
            }
            let response = self.deserializer.deserialize(page)
            if response.1 == nil {
                self.onPageLoad(response.0)
                completion(objects: response.0, error: nil)
            } else {
                completion(objects: [T](), error: self.jsonError)
            }
        }) { (task, error) in
            print("Failed to load: \((task?.originalRequest?.URL?.absoluteString)!)")
            self.loading = false
            completion(objects:[T]() ,error: error)
        }
    }
    
    func onPageLoad(objects: [T]) {
        if objects.count > 0 {
            self._objects.appendContentsOf(objects)
            if !self.preset.offsetById {
                self.offset += UInt64(objects.count)
            }
        }
    }
    
    private func formParameters(preset: PLPageCollectionPreset, offset: UInt64) -> [String : AnyObject] {
        var anOffset = offset
        if preset.offsetById {
            let lastId = objects.last?.id
            anOffset = lastId ?? 0
        }
        var params = [String : AnyObject]()
        params[preset.sizeKey] = String(preset.size)
        params[preset.offsetKey] = String(anOffset)
        if preset.id > 0 {
            params[preset.idKey] = String(preset.id)
        }
        if let moreParams = preset.params {
            for (key, value) in moreParams {
                params[key] = value
            }
        }
        return params
    }
    
    func clean() {
        filtered.removeAll()
        _objects.removeAll()
        offset = 0
    }
}

class PLPalsPageCollection<T: PLUniqueObject where T : PLFilterable> : PLPageCollection<T> {
    convenience init(url: String) {
        self.init(url: url, offsetById: true)
    }
    
    convenience init(url: String, offsetById: Bool) {
        let defaultSize = 20
        self.init(url: url, size: defaultSize, offsetById: offsetById)
    }
    
    init(url: String, size: Int, offsetById: Bool) {
        let offsetKey = offsetById ? PLKeys.since.string : PLKeys.page.string
        let preset = PLPageCollectionPreset(url: url, sizeKey: PLKeys.per_page.string, offsetKey: offsetKey, size: size, offsetById: offsetById)
        super.init(preset: preset)
    }
}

class PLUserPageCollection: PLPalsPageCollection<PLUser> {
    override init(url: String, size: Int, offsetById: Bool) {
        super.init(url: url, size: size, offsetById: offsetById)
    }
}