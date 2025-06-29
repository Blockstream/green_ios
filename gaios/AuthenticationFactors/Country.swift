import UIKit
import core
struct Country {
    let code: String
    let name: String
    let dialCode: Int
    var dialCodeString: String { "+\(dialCode)" }
    var flag: String {
        "\(code.uppercased())-flag"
    }
    init(_ code: String, _ name: String, _ dialCode: Int) {
        self.code = code
        self.name = name
        self.dialCode = dialCode
    }
    static func getCountlyRemoteConfigEnableBuyIosUk() -> Bool {
        return AnalyticsManager.shared.getRemoteConfigValue(key: AnalyticsManager.countlyRemoteConfigEnableBuyIosUk) as? Bool ?? false
    }
    static func allMeld() -> [Country] {
        let enableBuyIosUk = getCountlyRemoteConfigEnableBuyIosUk()
        return all()
            .filter {
                UIImage(named: $0.code.uppercased() + "-flag") != nil
            }.filter {
                enableBuyIosUk || $0.code != "gb"
            }
    }
    static func all() -> [Country] {
        
        return [
                Country("af", "Afghanistan (‫افغانستان‬‎)", 93),
                Country("al", "Albania (Shqipëri)", 355),
                Country("dz", "Algeria (‫الجزائر‬‎)", 213),
                Country("as", "American Samoa", 1684),
                Country("ad", "Andorra", 376),
                Country("ao", "Angola", 244),
                Country("ai", "Anguilla", 1264),
                Country("ag", "Antigua and Barbuda", 1268),
                Country("ar", "Argentina", 54),
                Country("am", "Armenia (Հայաստան)", 374),
                Country("aw", "Aruba", 297),
                Country("au", "Australia", 61),
                Country("at", "Austria (Österreich)", 43),
                Country("az", "Azerbaijan (Azərbaycan)", 994),
                Country("bs", "Bahamas", 1242),
                Country("bh", "Bahrain (‫البحرين‬‎)", 973),
                Country("bd", "Bangladesh (বাংলাদেশ)", 880),
                Country("bb", "Barbados", 1246),
                Country("by", "Belarus (Беларусь)", 375),
                Country("be", "Belgium (België)", 32),
                Country("bz", "Belize", 501),
                Country("bj", "Benin (Bénin)", 229),
                Country("bm", "Bermuda", 1441),
                Country("bt", "Bhutan (འབྲུག)", 975),
                Country("bo", "Bolivia", 591),
                Country("ba", "Bosnia and Herzegovina (Босна и Херцеговина)", 387),
                Country("bw", "Botswana", 267),
                Country("br", "Brazil (Brasil)", 55),
                Country("io", "British Indian Ocean Territory", 246),
                Country("vg", "British Virgin Islands", 1284),
                Country("bn", "Brunei", 673),
                Country("bg", "Bulgaria (България)", 359),
                Country("bf", "Burkina Faso", 226),
                Country("bi", "Burundi (Uburundi)", 257),
                Country("kh", "Cambodia (កម្ពុជា)", 855),
                Country("cm", "Cameroon (Cameroun)", 237),
                Country("ca", "Canada", 1),
                Country("cv", "Cape Verde (Kabu Verdi)", 238),
                Country("bq", "Caribbean Netherlands", 599),
                Country("ky", "Cayman Islands", 1345),
                Country("cf", "Central African Republic (République centrafricaine)", 236),
                Country("td", "Chad (Tchad)", 235),
                Country("cl", "Chile", 56),
                Country("cn", "China (中国)", 86),
                Country("cx", "Christmas Island", 61),
                Country("cc", "Cocos (Keeling) Islands", 61),
                Country("co", "Colombia", 57),
                Country("km", "Comoros (‫جزر القمر‬‎)", 269),
                Country("cd", "Congo (DRC) (Jamhuri ya Kidemokrasia ya Kongo)", 243),
                Country("cg", "Congo (Republic) (Congo-Brazzaville)", 242),
                Country("ck", "Cook Islands", 682),
                Country("cr", "Costa Rica", 506),
                Country("ci", "Côte d’Ivoire", 225),
                Country("hr", "Croatia (Hrvatska)", 385),
                Country("cu", "Cuba", 53),
                Country("cw", "Curaçao", 599),
                Country("cy", "Cyprus (Κύπρος)", 357),
                Country("cz", "Czech Republic (Česká republika)", 420),
                Country("dk", "Denmark (Danmark)", 45),
                Country("dj", "Djibouti", 253),
                Country("dm", "Dominica", 1767),
                Country("do", "Dominican Republic (República Dominicana)", 1),
                Country("ec", "Ecuador", 593),
                Country("eg", "Egypt (‫مصر‬‎)", 20),
                Country("sv", "El Salvador", 503),
                Country("gq", "Equatorial Guinea (Guinea Ecuatorial)", 240),
                Country("er", "Eritrea", 291),
                Country("ee", "Estonia (Eesti)", 372),
                Country("et", "Ethiopia", 251),
                Country("fk", "Falkland Islands (Islas Malvinas)", 500),
                Country("fo", "Faroe Islands (Føroyar)", 298),
                Country("fj", "Fiji", 679),
                Country("fi", "Finland (Suomi)", 358),
                Country("fr", "France", 33),
                Country("gf", "French Guiana (Guyane française)", 594),
                Country("pf", "French Polynesia (Polynésie française)", 689),
                Country("ga", "Gabon", 241),
                Country("gm", "Gambia", 220),
                Country("ge", "Georgia (საქართველო)", 995),
                Country("de", "Germany (Deutschland)", 49),
                Country("gh", "Ghana (Gaana)", 233),
                Country("gi", "Gibraltar", 350),
                Country("gr", "Greece (Ελλάδα)", 30),
                Country("gl", "Greenland (Kalaallit Nunaat)", 299),
                Country("gd", "Grenada", 1473),
                Country("gp", "Guadeloupe", 590),
                Country("gu", "Guam", 1671),
                Country("gt", "Guatemala", 502),
                Country("gg", "Guernsey", 44),
                Country("gn", "Guinea (Guinée)", 224),
                Country("gw", "Guinea-Bissau (Guiné Bissau)", 245),
                Country("gy", "Guyana", 592),
                Country("ht", "Haiti", 509),
                Country("hn", "Honduras", 504),
                Country("hk", "Hong Kong (香港)", 852),
                Country("hu", "Hungary (Magyarország)", 36),
                Country("is", "Iceland (Ísland)", 354),
                Country("in", "India (भारत)", 91),
                Country("id", "Indonesia", 62),
                Country("ir", "Iran (‫ایران‬‎)", 98),
                Country("iq", "Iraq (‫العراق‬‎)", 964),
                Country("ie", "Ireland", 353),
                Country("im", "Isle of Man", 44),
                Country("il", "Israel (‫ישראל‬‎)", 972),
                Country("it", "Italy (Italia)", 39),
                Country("jm", "Jamaica", 1876),
                Country("jp", "Japan (日本)", 81),
                Country("je", "Jersey", 44),
                Country("jo", "Jordan (‫الأردن‬‎)", 962),
                Country("kz", "Kazakhstan (Казахстан)", 7),
                Country("ke", "Kenya", 254),
                Country("ki", "Kiribati", 686),
                Country("kw", "Kuwait (‫الكويت‬‎)", 965),
                Country("kg", "Kyrgyzstan (Кыргызстан)", 996),
                Country("la", "Laos (ລາວ)", 856),
                Country("lv", "Latvia (Latvija)", 371),
                Country("lb", "Lebanon (‫لبنان‬‎)", 961),
                Country("ls", "Lesotho", 266),
                Country("lr", "Liberia", 231),
                Country("ly", "Libya (‫ليبيا‬‎)", 218),
                Country("li", "Liechtenstein", 423),
                Country("lt", "Lithuania (Lietuva)", 370),
                Country("lu", "Luxembourg", 352),
                Country("mo", "Macau (澳門)", 853),
                Country("mk", "Macedonia (FYROM) (Македонија)", 389),
                Country("mg", "Madagascar (Madagasikara)", 261),
                Country("mw", "Malawi", 265),
                Country("my", "Malaysia", 60),
                Country("mv", "Maldives", 960),
                Country("ml", "Mali", 223),
                Country("mt", "Malta", 356),
                Country("mh", "Marshall Islands", 692),
                Country("mq", "Martinique", 596),
                Country("mr", "Mauritania (‫موريتانيا‬‎)", 222),
                Country("mu", "Mauritius (Moris)", 230),
                Country("yt", "Mayotte", 262),
                Country("mx", "Mexico (México)", 52),
                Country("fm", "Micronesia", 691),
                Country("md", "Moldova (Republica Moldova)", 373),
                Country("mc", "Monaco", 377),
                Country("mn", "Mongolia (Монгол)", 976),
                Country("me", "Montenegro (Crna Gora)", 382),
                Country("ms", "Montserrat", 1664),
                Country("ma", "Morocco (‫المغرب‬‎)", 212),
                Country("mz", "Mozambique (Moçambique)", 258),
                Country("mm", "Myanmar (Burma) (မြန်မာ)", 95),
                Country("na", "Namibia (Namibië)", 264),
                Country("nr", "Nauru", 674),
                Country("np", "Nepal (नेपाल)", 977),
                Country("nl", "Netherlands (Nederland)", 31),
                Country("nc", "New Caledonia (Nouvelle-Calédonie)", 687),
                Country("nz", "New Zealand", 64),
                Country("ni", "Nicaragua", 505),
                Country("ne", "Niger (Nijar)", 227),
                Country("ng", "Nigeria", 234),
                Country("nu", "Niue", 683),
                Country("nf", "Norfolk Island", 672),
                Country("kp", "North Korea (조선 민주주의 인민 공화국)", 850),
                Country("mp", "Northern Mariana Islands", 1670),
                Country("no", "Norway (Norge)", 47),
                Country("om", "Oman (‫عُمان‬‎)", 968),
                Country("pk", "Pakistan (‫پاکستان‬‎)", 92),
                Country("pw", "Palau", 680),
                Country("ps", "Palestine (‫فلسطين‬‎)", 970),
                Country("pa", "Panama (Panamá)", 507),
                Country("pg", "Papua New Guinea", 675),
                Country("py", "Paraguay", 595),
                Country("pe", "Peru (Perú)", 51),
                Country("ph", "Philippines", 63),
                Country("pl", "Poland (Polska)", 48),
                Country("pt", "Portugal", 351),
                Country("pr", "Puerto Rico", 1),
                Country("qa", "Qatar (‫قطر‬‎)", 974),
                Country("re", "Réunion (La Réunion)", 262),
                Country("ro", "Romania (România)", 40),
                Country("ru", "Russia (Россия)", 7),
                Country("rw", "Rwanda", 250),
                Country("bl", "Saint Barthélemy (Saint-Barthélemy)", 590),
                Country("sh", "Saint Helena", 290),
                Country("kn", "Saint Kitts and Nevis", 1869),
                Country("lc", "Saint Lucia", 1758),
                Country("mf", "Saint Martin (Saint-Martin (partie française),", 590),
                Country("pm", "Saint Pierre and Miquelon (Saint-Pierre-et-Miquelon)", 508),
                Country("vc", "Saint Vincent and the Grenadines", 1784),
                Country("ws", "Samoa", 685),
                Country("sm", "San Marino", 378),
                Country("st", "São Tomé and Príncipe (São Tomé e Príncipe)", 239),
                Country("sa", "Saudi Arabia (‫المملكة العربية السعودية‬‎)", 966),
                Country("sn", "Senegal (Sénégal)", 221),
                Country("rs", "Serbia (Србија)", 381),
                Country("sc", "Seychelles", 248),
                Country("sl", "Sierra Leone", 232),
                Country("sg", "Singapore", 65),
                Country("sx", "Sint Maarten", 1721),
                Country("sk", "Slovakia (Slovensko)", 421),
                Country("si", "Slovenia (Slovenija)", 386),
                Country("sb", "Solomon Islands", 677),
                Country("so", "Somalia (Soomaaliya)", 252),
                Country("za", "South Africa", 27),
                Country("kr", "South Korea (대한민국)", 82),
                Country("ss", "South Sudan (‫جنوب السودان‬‎)", 211),
                Country("es", "Spain (España)", 34),
                Country("lk", "Sri Lanka (ශ්‍රී ලංකාව)", 94),
                Country("sd", "Sudan (‫السودان‬‎)", 249),
                Country("sr", "Suriname", 597),
                Country("sj", "Svalbard and Jan Mayen", 47),
                Country("sz", "Swaziland", 268),
                Country("se", "Sweden (Sverige)", 46),
                Country("ch", "Switzerland (Schweiz)", 41),
                Country("sy", "Syria (‫سوريا‬‎)", 963),
                Country("tw", "Taiwan (台灣)", 886),
                Country("tj", "Tajikistan", 992),
                Country("tz", "Tanzania", 255),
                Country("th", "Thailand (ไทย)", 66),
                Country("tl", "Timor-Leste", 670),
                Country("tg", "Togo", 228),
                Country("tk", "Tokelau", 690),
                Country("to", "Tonga", 676),
                Country("tt", "Trinidad and Tobago", 1868),
                Country("tn", "Tunisia (‫تونس‬‎)", 216),
                Country("tr", "Turkey (Türkiye)", 90),
                Country("tm", "Turkmenistan", 993),
                Country("tc", "Turks and Caicos Islands", 1649),
                Country("tv", "Tuvalu", 688),
                Country("vi", "U.S. Virgin Islands", 1340),
                Country("ug", "Uganda", 256),
                Country("ua", "Ukraine (Україна)", 380),
                Country("ae", "United Arab Emirates (‫الإمارات العربية المتحدة‬‎)", 971),
                Country("gb", "United Kingdom", 44),
                Country("us", "United States", 1),
                Country("uy", "Uruguay", 598),
                Country("uz", "Uzbekistan (Oʻzbekiston)", 998),
                Country("vu", "Vanuatu", 678),
                Country("va", "Vatican City (Città del Vaticano)", 39),
                Country("ve", "Venezuela", 58),
                Country("vn", "Vietnam (Việt Nam)", 84),
                Country("wf", "Wallis and Futuna", 681),
                Country("eh", "Western Sahara (‫الصحراء الغربية‬‎)", 212),
                Country("ye", "Yemen (‫اليمن‬‎)", 967),
                Country("zm", "Zambia", 260),
                Country("zw", "Zimbabwe", 263),
                Country("ax", "Åland Islands", 358)
            ]

    }

    static func pickerItems() -> [GreenPickerItem] {
        var list: [GreenPickerItem] = []
        for c in Country.all() {
            list.append(GreenPickerItem(code: c.code, title: c.name, hint: c.dialCodeString))
        }
        return list
    }
}
