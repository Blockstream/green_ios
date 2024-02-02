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
    var mainQuestion: String?
    var followUpAll: String?
    var followUpPromoter: String?
    var followUpPassive: String?
    var followUpDetractor: String?
    var thanks: String?
}

public struct WidgetAppearance: Decodable {
    var show: String?
    var color: String?
    var style: String?
    var submit: String?
    var followUpInput: String?
    var notLikely: String?
    var likely: String?
}

public struct WidgetQuestion: Decodable {
    var type: String?
    var question: String?
    var required: Bool?
    var other: Bool?
    var allOfTheAbove: Bool?
    var noneOfTheAbove: Bool?
    var otherText: String?
    var allOfTheAboveText: String?
    var noneOfTheAboveText: String?
    var notLikely: String?
    var likely: String?
    var id: String?

    public var qType: WidgetQuestionType {
        guard let value = WidgetQuestionType(rawValue: self.type ?? "") else {
            return .undefined
        }
        return value
    }
}
