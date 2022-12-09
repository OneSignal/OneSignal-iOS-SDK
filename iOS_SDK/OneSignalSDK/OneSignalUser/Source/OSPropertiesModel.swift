/*
 Modified MIT License

 Copyright 2022 OneSignal

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 1. The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 2. All copies of substantial portions of the Software may only be used in connection
 with services provided by OneSignal.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

import Foundation
import OneSignalOSCore

class OSPropertiesModel: OSModel {
    var language: String? {
        didSet {
            self.set(property: "language", newValue: language)
        }
    }
    
    var lat: Float? {
        didSet {
            self.set(property: "lat", newValue: lat)
        }
    }
    
    var long: Float? {
        didSet {
            self.set(property: "long", newValue: long)
        }
    }

    var tags: [String: String] = [:]

    // TODO: Purchase tracking

    // MARK: - Initialization

    // We seem to lose access to this init() in superclass after adding init?(coder: NSCoder)
    override init(changeNotifier: OSEventProducer<OSModelChangedHandler>) {
        super.init(changeNotifier: changeNotifier)
    }

    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(language, forKey: "language")
        coder.encode(tags, forKey: "tags")
        // ... and more
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        language = coder.decodeObject(forKey: "language") as? String
        guard let tags = coder.decodeObject(forKey: "tags") as? [String: String] else {
            // log error
            return
        }
        self.tags = tags

        // ... and more
    }

    // MARK: - Tag Methods

    func setTags(_ tags: [String: String]) {
        for (key, value) in tags {
            self.tags[key] = value
        }
        self.set(property: "tags", newValue: tags)
    }

    func removeTags(_ tags: [String]) {
        var tagsToSend: [String: String] = [:]
        for tag in tags {
            self.tags.removeValue(forKey: tag)
            tagsToSend[tag] = ""
        }
        self.set(property: "aliases", newValue: tagsToSend)
    }

    public override func hydrateModel(_ response: [String: String]) {
        // TODO: Update Model properties with the response
    }
}
