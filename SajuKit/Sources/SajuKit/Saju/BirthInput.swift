import Foundation

/// 성별 — 대운 순역 판정에 사용.
public enum Gender: String, Sendable, Codable, CaseIterable {
    case male = "남"
    case female = "여"
}

/// 출생지 — 진태양시 보정의 기준 경도.
public struct BirthPlace: Sendable, Codable, Hashable {
    public let name: String
    /// 동경 기준 경도(도). 서울 126.978.
    public let longitude: Double
    /// IANA 시간대 식별자. 역사적 표준시·서머타임을 Foundation이 처리한다.
    public let timeZoneIdentifier: String

    public init(name: String, longitude: Double, timeZoneIdentifier: String = "Asia/Seoul") {
        self.name = name
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public static let seoul = BirthPlace(name: "서울", longitude: 126.978)
}

/// 계산 옵션 — 유파 차이를 명시적 설정으로 노출한다.
public struct SajuOptions: Sendable, Codable, Hashable {
    /// 진태양시 보정 방식.
    public enum SolarTimeMode: String, Sendable, Codable, CaseIterable {
        /// 출생지 경도 기반 평균태양시 (기본). 서울 −32분.
        case longitude
        /// 동경 135도 고정 −30분 (일부 만세력 관행).
        case fixedMinus30
        /// 보정 없음 — 표준시 그대로.
        case none
    }

    /// 자시 경계 처리.
    public enum JasiPolicy: String, Sendable, Codable, CaseIterable {
        /// 야자시·조자시 구분 (기본): 23시대 출생은 당일 일주 + 익일 자시 시두.
        case yajasi
        /// 자시일수: 23시부터 일주가 다음 날로 넘어간다.
        case rollover
    }

    /// 대운수 끝처리.
    public enum DaeunRounding: String, Sendable, Codable, CaseIterable {
        /// 3일 = 1년, 나머지 반올림 (1일 버림·2일 올림) — 통용 관행.
        case round
        /// 버림.
        case floor
    }

    public var solarTimeMode: SolarTimeMode
    /// 균시차 반영 여부 (기본 꺼짐 — 국내 만세력 통례).
    public var applyEquationOfTime: Bool
    public var jasiPolicy: JasiPolicy
    public var daeunRounding: DaeunRounding

    public init(
        solarTimeMode: SolarTimeMode = .longitude,
        applyEquationOfTime: Bool = false,
        jasiPolicy: JasiPolicy = .yajasi,
        daeunRounding: DaeunRounding = .round
    ) {
        self.solarTimeMode = solarTimeMode
        self.applyEquationOfTime = applyEquationOfTime
        self.jasiPolicy = jasiPolicy
        self.daeunRounding = daeunRounding
    }

    public static let `default` = SajuOptions()
}

/// 출생 정보 입력.
public struct BirthInput: Sendable, Codable, Hashable {
    public enum CalendarType: Sendable, Codable, Hashable {
        case solar
        case lunar(isLeapMonth: Bool)
    }

    public var year: Int
    public var month: Int
    public var day: Int
    /// 시·분. nil이면 시간 미상 — 시주 없이 삼주로 계산.
    public var hour: Int?
    public var minute: Int
    public var calendarType: CalendarType
    public var gender: Gender
    public var place: BirthPlace
    public var options: SajuOptions

    public init(
        year: Int, month: Int, day: Int,
        hour: Int? = nil, minute: Int = 0,
        calendarType: CalendarType = .solar,
        gender: Gender,
        place: BirthPlace = .seoul,
        options: SajuOptions = .default
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.calendarType = calendarType
        self.gender = gender
        self.place = place
        self.options = options
    }
}
