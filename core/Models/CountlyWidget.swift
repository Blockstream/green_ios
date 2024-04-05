import Foundation

public enum CountlyWidgetType: String {
    case nps
    case survey
    case undefined
}

public enum SurveyFollowUpType: String {
    case score
    case one
    case none
}

public enum WidgetQuestionType: String {
    case rating
    case text
    case undefined
}

public struct CountlyWidget: Decodable {
    public var _id: String?
    public var app_id: String?
    public var name: String?
    public var msg: WidgetMessage?
    public var appearance: WidgetAppearance?
    public var type: String?
    public var followUpType: String?
    public var questions: [WidgetQuestion]?

    public static func build(_ widget: [AnyHashable: Any]) -> CountlyWidget? {
        let json = try? JSONSerialization.data(withJSONObject: widget, options: [])
        let w = try? JSONDecoder().decode(CountlyWidget.self, from: json ?? Data())
        return w
    }

    public var wType: CountlyWidgetType {
        guard let value = CountlyWidgetType(rawValue: self.type ?? "") else {
            return .undefined
        }
        return value
    }

    public var wFollowUpType: SurveyFollowUpType {
        guard let value = SurveyFollowUpType(rawValue: self.followUpType ?? "") else {
            return .none
        }
        return value
    }
}

public struct WidgetMessage: Decodable {
    public var mainQuestion: String?
    public var followUpAll: String?
    public var followUpPromoter: String?
    public var followUpPassive: String?
    public var followUpDetractor: String?
    public var thanks: String?
    public init(mainQuestion: String? = nil, followUpAll: String? = nil, followUpPromoter: String? = nil, followUpPassive: String? = nil, followUpDetractor: String? = nil, thanks: String? = nil) {
        self.mainQuestion = mainQuestion
        self.followUpAll = followUpAll
        self.followUpPromoter = followUpPromoter
        self.followUpPassive = followUpPassive
        self.followUpDetractor = followUpDetractor
        self.thanks = thanks
    }
}

public struct WidgetAppearance: Decodable {
    public var show: String?
    public var color: String?
    public var style: String?
    public var submit: String?
    public var followUpInput: String?
    public var notLikely: String?
    public var likely: String?
    public init(show: String? = nil, color: String? = nil, style: String? = nil, submit: String? = nil, followUpInput: String? = nil, notLikely: String? = nil, likely: String? = nil) {
        self.show = show
        self.color = color
        self.style = style
        self.submit = submit
        self.followUpInput = followUpInput
        self.notLikely = notLikely
        self.likely = likely
    }
}

public struct WidgetQuestion: Decodable {
    public var type: String?
    public var question: String?
    public var required: Bool?
    public var other: Bool?
    public var allOfTheAbove: Bool?
    public var noneOfTheAbove: Bool?
    public var otherText: String?
    public var allOfTheAboveText: String?
    public var noneOfTheAboveText: String?
    public var notLikely: String?
    public var likely: String?
    public var id: String?

    public var qType: WidgetQuestionType {
        guard let value = WidgetQuestionType(rawValue: self.type ?? "") else {
            return .undefined
        }
        return value
    }
    public init(type: String? = nil, question: String? = nil, required: Bool? = nil, other: Bool? = nil, allOfTheAbove: Bool? = nil, noneOfTheAbove: Bool? = nil, otherText: String? = nil, allOfTheAboveText: String? = nil, noneOfTheAboveText: String? = nil, notLikely: String? = nil, likely: String? = nil, id: String? = nil) {
        self.type = type
        self.question = question
        self.required = required
        self.other = other
        self.allOfTheAbove = allOfTheAbove
        self.noneOfTheAbove = noneOfTheAbove
        self.otherText = otherText
        self.allOfTheAboveText = allOfTheAboveText
        self.noneOfTheAboveText = noneOfTheAboveText
        self.notLikely = notLikely
        self.likely = likely
        self.id = id
    }
}
