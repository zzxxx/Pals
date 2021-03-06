//
//  PLDrinksDatasource
//  Pals
//
//  Created by Maks Sergeychuk on 9/27/16.
//  Copyright © 2016 citirex. All rights reserved.
//

class PLEventsDatasource: PLDatasource<PLEvent> {
    
    var placeId: UInt64? {
        didSet {
            if let id = placeId {
                collection.appendParams([PLKey.place_id.string : String(id)])
            }
        }
    }
    
    override init(url: String, params: PLURLParams?, offsetById: Bool, sectioned: Bool) {
        super.init(url: url, params: params, offsetById: offsetById, sectioned: sectioned)
    }
    
    convenience init() {
        self.init(url: PLAPIService.Events.string, offsetById: false)
        collection.appendPath([PLKey.events.string])
    }
    
    override func fakeFeedFilenameKey() -> String {
        return PLKey.events.string
    }
}
