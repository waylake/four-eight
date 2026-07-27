import Foundation

/// 사주 계산 엔진.
///
/// 원칙: 년주·월주는 절기 "순간"(UTC) 비교로, 일주·시주는 진태양시로
/// 판정한다. 역사적 표준시와 서머타임은 IANA tzdb(Foundation)가 처리한다.
public enum PillarsEngine {
    public enum EngineError: Error, Sendable {
        case invalidDate
        case lunarConversionFailed
        case unsupportedYear
    }

    /// 지원 범위 — 절기·음양력 정밀도가 검증된 구간.
    public static let supportedYears = 1900...2100

    public static func chart(for input: BirthInput) throws -> SajuChart {
        // 1. 음력 입력이면 양력으로.
        let (sy, sm, sd): (Int, Int, Int)
        var lunarDate: LunarDate?
        switch input.calendarType {
        case .solar:
            (sy, sm, sd) = (input.year, input.month, input.day)
            lunarDate = KoreanLunarCalendar.lunar(fromSolarYear: sy, month: sm, day: sd)
        case .lunar(let isLeap):
            let ld = LunarDate(year: input.year, month: input.month, day: input.day, isLeapMonth: isLeap)
            guard let solar = KoreanLunarCalendar.solar(from: ld) else {
                throw EngineError.lunarConversionFailed
            }
            (sy, sm, sd) = solar
            lunarDate = ld
        }
        guard supportedYears.contains(sy) else { throw EngineError.unsupportedYear }

        // 2. 벽시계 → UTC 순간. tzdb가 표준시 연혁·서머타임을 적용한다.
        guard let tz = TimeZone(identifier: input.place.timeZoneIdentifier) else {
            throw EngineError.invalidDate
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        var comps = DateComponents()
        comps.year = sy
        comps.month = sm
        comps.day = sd
        comps.hour = input.hour ?? 12   // 시간 미상 시 정오로 일주 판정.
        comps.minute = input.minute
        guard let utcInstant = cal.date(from: comps) else { throw EngineError.invalidDate }
        let utcOffset = tz.secondsFromGMT(for: utcInstant)
        let isDST = tz.isDaylightSavingTime(for: utcInstant)

        // 3. 진태양시.
        let longitudeMinutes: Double
        switch input.options.solarTimeMode {
        case .longitude:
            longitudeMinutes = input.place.longitude * 4 - 540   // KST(135°) 대비 표시용
        case .fixedMinus30:
            longitudeMinutes = -30
        case .none:
            longitudeMinutes = 0
        }
        // 평균태양시 = UTC + 경도/15h. 모드별 유효 경도로 환산.
        let effectiveLongitude: Double
        switch input.options.solarTimeMode {
        case .longitude: effectiveLongitude = input.place.longitude
        case .fixedMinus30: effectiveLongitude = 127.5           // 135° − 7.5°(30분)
        case .none: effectiveLongitude = 135.0
        }
        var solarInstant = utcInstant.addingTimeInterval(effectiveLongitude * 240)
        var eotMinutes = 0.0
        if input.options.applyEquationOfTime {
            let jde = DeltaT.tt(fromUT: JulianDay.jd(from: utcInstant))
            eotMinutes = Solar.equationOfTimeMinutes(jde: jde)
            solarInstant = solarInstant.addingTimeInterval(eotMinutes * 60)
        }

        // 태양시의 날짜·시각 성분 (UTC 달력으로 읽으면 벽시계 성분이 나온다).
        let utcCal = Calendar.gregorianUTC
        let c = utcCal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: solarInstant)
        let solarJDN = JulianDay.jdn(year: c.year!, month: c.month!, day: c.day!)
        let secondsOfDay = c.hour! * 3600 + c.minute! * 60 + c.second!

        // 4. 년주 — 입춘 순간 기준.
        let gregorianYearUTC = utcCal.component(.year, from: utcInstant)
        var sajuYear = gregorianYearUTC
        if utcInstant < SolarTerms.instant(of: .ipchun, year: gregorianYearUTC) {
            sajuYear -= 1
        }
        let yearPillar = Ganji(
            stem: Cheongan(rawValue: ((sajuYear - 4) % 10 + 10) % 10)!,
            branch: Jiji(rawValue: ((sajuYear - 4) % 12 + 12) % 12)!
        )

        // 5. 월주 — 관할 절(節) 기준, 월두법.
        let jeol = SolarTerms.governingJeol(at: utcInstant)
        let monthBranch = jeol.term.monthBranch!
        // 인월(입춘) 기준 오프셋: 인=0 … 축=11.
        let monthOffset = (monthBranch.rawValue - Jiji.inn.rawValue + 12) % 12
        let monthStem = Cheongan(rawValue: (yearPillar.stem.rawValue % 5 * 2 + 2 + monthOffset) % 10)!
        let monthPillar = Ganji(stem: monthStem, branch: monthBranch)

        // 6. 일주·시주 — 진태양시 기준.
        var dayJDN = solarJDN
        var hourPillar: Ganji?
        var isNightJasi = false
        if let _ = input.hour {
            let hourDecimal = Double(secondsOfDay) / 3600.0
            let branchIndex = Int(floor((hourDecimal + 1) / 2)) % 12
            let hourBranch = Jiji(rawValue: branchIndex)!
            // 자시 경계 정책.
            var stemDayJDN = dayJDN
            if hourBranch == .ja && hourDecimal >= 23 {
                switch input.options.jasiPolicy {
                case .yajasi:
                    isNightJasi = true
                    stemDayJDN = dayJDN + 1   // 시두만 익일 일간.
                case .rollover:
                    dayJDN += 1               // 일주 자체가 익일로.
                    stemDayJDN = dayJDN
                }
            }
            let stemDayStem = Cheongan(rawValue: ((stemDayJDN + 49) % 60) % 10)
            let hourStem = Cheongan(
                rawValue: (stemDayStem!.rawValue % 5 * 2 + hourBranch.rawValue) % 10
            )!
            hourPillar = Ganji(stem: hourStem, branch: hourBranch)
        }
        let dayPillar = Ganji(cycleIndex: (dayJDN + 49) % 60)

        return SajuChart(
            input: input,
            solarYear: sy, solarMonth: sm, solarDay: sd,
            lunarDate: lunarDate,
            yearPillar: yearPillar,
            monthPillar: monthPillar,
            dayPillar: dayPillar,
            hourPillar: hourPillar,
            isNightJasi: isNightJasi,
            sajuYear: sajuYear,
            governingJeol: jeol.term,
            corrections: TimeCorrections(
                utcOffsetSeconds: utcOffset,
                isDST: isDST,
                longitudeCorrectionMinutes: longitudeMinutes,
                equationOfTimeMinutes: eotMinutes,
                solarTimeSecondsOfDay: secondsOfDay,
                solarDateJDN: solarJDN
            )
        )
    }

    /// 특정 UTC 순간의 일진(日辰) — 오늘의 간지 등 캘린더 용도.
    /// 진태양시 보정 없이 해당 시간대 벽시계 날짜 기준.
    public static func dayGanji(on date: Date, timeZone: TimeZone) -> Ganji {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let jdn = JulianDay.jdn(year: c.year!, month: c.month!, day: c.day!)
        return Ganji(cycleIndex: (jdn + 49) % 60)
    }

    /// 특정 그레고리력 연도의 세운 간지 (입춘 기준 연도 표기).
    public static func yearGanji(forSajuYear year: Int) -> Ganji {
        Ganji(
            stem: Cheongan(rawValue: ((year - 4) % 10 + 10) % 10)!,
            branch: Jiji(rawValue: ((year - 4) % 12 + 12) % 12)!
        )
    }
}
