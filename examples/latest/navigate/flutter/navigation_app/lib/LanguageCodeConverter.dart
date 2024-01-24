/*
 * Copyright (C) 2019-2024 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License")
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 * License-Filename: LICENSE
 */

import 'dart:ui';

import 'package:here_sdk/core.dart';

// Converts from HERE SDK's LanguageCode to Locale and vice versa.
// Both language and country must be set, if available.
class LanguageCodeConverter {
  // Language is always set, region may not be set.
  static final Map<LanguageCode, Locale> _languageCodeMap = {
    /// English (United States)
    LanguageCode.enUs: Locale("en", "US"),

    /// Afrikaans
    LanguageCode.afZa: Locale("af", "ZA"),

    /// Albanian
    LanguageCode.sqAl: Locale("sq", "AL"),

    /// Amharic (Ethiopia)
    LanguageCode.amEt: Locale("am", "ET"),

    /// Arabic (Saudi Arabia)
    LanguageCode.arSa: Locale("ar", "SA"),

    /// Armenian
    LanguageCode.hyAm: Locale("hy", "AM"),

    /// Assamese (India)
    LanguageCode.asIn: Locale("as", "IN"),

    /// Azeri - Latin
    LanguageCode.azLatnAz: Locale("az", "LATN_AZ"),

    /// Bangla (Bangladesh)
    LanguageCode.bnBd: Locale("bn", "BD"),

    /// Bangla (India)
    LanguageCode.bnIn: Locale("bn", "IN"),

    /// Basque
    LanguageCode.euEs: Locale("eu", "ES"),

    /// Belarusian
    LanguageCode.beBy: Locale("be", "BY"),

    /// Bosnian - Latin
    LanguageCode.bsLatnBa: Locale("bs", "LATN_BA"),

    /// Bulgarian
    LanguageCode.bgBg: Locale("bg", "BG"),

    /// Catalan (Spain)
    LanguageCode.caEs: Locale("ca", "ES"),

    /// Central Kurdish - Arabic
    LanguageCode.kuArab: Locale("ku", "ARAB"),

    /// Chinese (Simplified China)
    LanguageCode.zhCn: Locale("zh", "CN"),

    /// Chinese (Traditional Hong Kong)
    LanguageCode.zhHk: Locale("zh", "HK"),

    /// Chinese (Traditional Taiwan)
    LanguageCode.zhTw: Locale("zh", "TW"),

    /// Croatian
    LanguageCode.hrHr: Locale("hr", "HR"),

    /// Czech
    LanguageCode.csCz: Locale("cs", "CZ"),

    /// Danish
    LanguageCode.daDk: Locale("da", "DK"),

    /// Dari - Arabic (Afghanistan)
    LanguageCode.prsArabAf: Locale("prs", "ARAB_AF"),

    /// Dutch
    LanguageCode.nlNl: Locale("nl", "NL"),

    /// English (British)
    LanguageCode.enGb: Locale("en", "GB"),

    /// Estonian
    LanguageCode.etEe: Locale("et", "EE"),

    /// Farsi (Iran)
    LanguageCode.faIr: Locale("fa", "IR"),

    /// Filipino
    LanguageCode.filPh: Locale("fil", "PH"),

    /// Finnish
    LanguageCode.fiFi: Locale("fi", "FI"),

    /// French
    LanguageCode.frFr: Locale("fr", "FR"),

    /// French (Canada)
    LanguageCode.frCa: Locale("fr", "CA"),

    /// Galician
    LanguageCode.glEs: Locale("gl", "ES"),

    /// Georgian
    LanguageCode.kaGe: Locale("ka", "GE"),

    /// German
    LanguageCode.deDe: Locale("de", "DE"),

    /// Greek
    LanguageCode.elGr: Locale("el", "GR"),

    /// Gujarati (India)
    LanguageCode.guIn: Locale("gu", "IN"),

    /// Hausa - Latin (Nigeria)
    LanguageCode.haLatnNg: Locale("ha", "LATN_NG"),

    /// Hebrew
    LanguageCode.heIl: Locale("he", "IL"),

    /// Hindi
    LanguageCode.hiIn: Locale("hi", "IN"),

    /// Hungarian
    LanguageCode.huHu: Locale("hu", "HU"),

    /// Icelandic
    LanguageCode.isIs: Locale("is", "IS"),

    /// Igbo - Latin (Nigera)
    LanguageCode.igLatnNg: Locale("ig", "LATN_NG"),

    /// Indonesian (Bahasa)
    LanguageCode.idId: Locale("id", "ID"),

    /// Irish
    LanguageCode.gaIe: Locale("ga", "IE"),

    /// IsiXhosa
    LanguageCode.xh: Locale("xh"),

    /// IsiZulu (South Africa)
    LanguageCode.zuZa: Locale("zu", "ZA"),

    /// Italian
    LanguageCode.itIt: Locale("it", "IT"),

    /// Japanese
    LanguageCode.jaJp: Locale("ja", "JP"),

    /// Kannada (India)
    LanguageCode.knIn: Locale("kn", "IN"),

    /// Kazakh
    LanguageCode.kkKz: Locale("kk", "KZ"),

    /// Khmer (Cambodia)
    LanguageCode.kmKh: Locale("km", "KH"),

    /// K'iche' - Latin (Guatemala)
    LanguageCode.qucLatnGt: Locale("quc", "LATN_GT"),

    /// Kinyarwanda (Rwanda)
    LanguageCode.rwRw: Locale("rw", "RW"),

    /// KiSwahili
    LanguageCode.sw: Locale("sw"),

    /// Konkani (India)
    LanguageCode.kokIn: Locale("kok", "IN"),

    /// Korean
    LanguageCode.koKr: Locale("ko", "KR"),

    /// Kyrgyz - Cyrillic
    LanguageCode.kyCyrlKg: Locale("ky", "CYRL_KG"),

    /// Latvian
    LanguageCode.lvLv: Locale("lv", "LV"),

    /// Lithuanian
    LanguageCode.ltLt: Locale("lt", "LT"),

    /// Luxembourgish
    LanguageCode.lbLu: Locale("lb", "LU"),

    /// Macedonian
    LanguageCode.mkMk: Locale("mk", "MK"),

    /// Malay (Bahasa)
    LanguageCode.msMy: Locale("ms", "MY"),

    /// Malayalam (India)
    LanguageCode.mlIn: Locale("ml", "IN"),

    /// Maltese  (Malta)
    LanguageCode.mtMt: Locale("mt", "MT"),

    /// Maori - Latin (New Zealand)
    LanguageCode.miLatnNz: Locale("mi", "LATN_NZ"),

    /// Marathi (India)
    LanguageCode.mrIn: Locale("mr", "IN"),

    /// Mongolian - Cyrillic
    LanguageCode.mnCyrlMn: Locale("mn", "CYRL_MN"),

    /// Nepali (Nepal)
    LanguageCode.neNp: Locale("ne", "NP"),

    /// Norwegian (Bokmål)
    LanguageCode.nbNo: Locale("nb", "NO"),

    /// Norwegian (Nynorsk)
    LanguageCode.nnNo: Locale("nn", "NO"),

    /// Odia (India)
    LanguageCode.orIn: Locale("or", "IN"),

    /// Polish
    LanguageCode.plPl: Locale("pl", "PL"),

    /// Portuguese (Brazil)
    LanguageCode.ptBr: Locale("pt", "BR"),

    /// Portuguese (Portugal)
    LanguageCode.ptPt: Locale("pt", "PT"),

    /// Punjabi - Gurmukhi
    LanguageCode.paGuru: Locale("pa", "GURU"),

    /// Punjabi - Arabic
    LanguageCode.paArab: Locale("pa", "ARAB"),

    /// Quechua - Latin (Peru)
    LanguageCode.quLatnPe: Locale("qu", "LATN_PE"),

    /// Romanian
    LanguageCode.roRo: Locale("ro", "RO"),

    /// Russian
    LanguageCode.ruRu: Locale("ru", "RU"),

    /// Scottish Gaelic - Latin
    LanguageCode.gdLatnGb: Locale("gd", "LATN_GB"),

    /// Serbian - Cyrillic (Bosnia)
    LanguageCode.srCyrlBa: Locale("sr", "CYRL_BA"),

    /// Serbian - Cyrillic (Serbia)
    LanguageCode.srCyrlRs: Locale("sr", "CYRL_RS"),

    /// Serbian - Latin (Serbia)
    LanguageCode.srLatnRs: Locale("sr", "LATN_RS"),

    /// Sesotho Sa Leboa (South Africa)
    LanguageCode.nsoZa: Locale("nso", "ZA"),

    /// Setswana
    LanguageCode.tn: Locale("tn"),

    /// Sindhi - Arabic
    LanguageCode.sdArab: Locale("sd", "ARAB"),

    /// Sinhala (Sri Lanka)
    LanguageCode.siLk: Locale("si", "LK"),

    /// Slovak
    LanguageCode.skSk: Locale("sk", "SK"),

    /// Slovenian
    LanguageCode.slSi: Locale("sl", "SI"),

    /// Spanish (Mexico)
    LanguageCode.esMx: Locale("es", "MX"),

    /// Spanish (Spain)
    LanguageCode.esEs: Locale("es", "ES"),

    /// Swedish
    LanguageCode.svSe: Locale("sv", "SE"),

    /// Tajik - Cyrillic
    LanguageCode.tgCyrlTj: Locale("tg", "CYRL_TJ"),

    /// Tamil
    LanguageCode.ta: Locale("ta"),

    /// Tatar - Cyrillic (Russia)
    LanguageCode.ttCyrlRu: Locale("tt", "CYRL_RU"),

    /// Telugu (India)
    LanguageCode.teIn: Locale("te", "IN"),

    /// Thai
    LanguageCode.thTh: Locale("th", "TH"),

    /// Tigrinya (Ethiopia)
    LanguageCode.tiEt: Locale("ti", "ET"),

    /// Turkish
    LanguageCode.trTr: Locale("tr", "TR"),

    /// Turkmen - Latin
    LanguageCode.tkLatnTm: Locale("tk", "LATN_TM"),

    /// Ukrainian
    LanguageCode.ukUa: Locale("uk", "UA"),

    /// Urdu
    LanguageCode.ur: Locale("ur"),

    /// Uyghur - Arabic
    LanguageCode.ugArab: Locale("ug", "ARAB"),

    /// Uzbek - Cyrillic
    LanguageCode.uzCyrlUz: Locale("uz", "CYRL_UZ"),

    /// Uzbek - Latin
    LanguageCode.uzLatnUz: Locale("uz", "LATN_UZ"),

    /// Valencian (Spain)
    LanguageCode.catEs: Locale("cat", "ES"),

    /// Vietnamese
    LanguageCode.viVn: Locale("vi", "VN"),

    /// Welsh
    LanguageCode.cyGb: Locale("cy", "GB"),

    /// Wolof - Latin
    LanguageCode.woLatn: Locale("wo", "LATN"),

    /// Yoruba - Latin
    LanguageCode.yoLatn: Locale("yo", "LATN")
  };

  static Locale getLocale(LanguageCode languageCode) {
    if (!_languageCodeMap.containsKey(languageCode)) {
      // Should never happen, unless the languageCodeMap was not updated
      // to support the latest LanguageCodes from HERE SDK.
      return Locale("en", "US");
    }

    return _languageCodeMap[languageCode]!;
  }

  static LanguageCode getLanguageCode(Locale locale) {
    var language = locale.languageCode;
    var country = locale.countryCode;

    for (var languageCodeEntry in _languageCodeMap.keys) {
      if (country == null) {
        if (language == _languageCodeMap[languageCodeEntry]!.languageCode) {
          return languageCodeEntry;
        }
      } else {
        if (language == _languageCodeMap[languageCodeEntry]!.languageCode &&
            country == _languageCodeMap[languageCodeEntry]!.countryCode) {
          return languageCodeEntry;
        }
      }
    }

    print("LanguageCode not found. Falling back to enUs.");
    return LanguageCode.enUs;
  }

  static LanguageCode getLanguageCodeFromIdentifier(String identifier) {
    for (var languageCodeEntry in _languageCodeMap.keys) {
      if (identifier == _languageCodeMap[languageCodeEntry]!.toLanguageTag()) {
        return languageCodeEntry;
      }
    }

    print("LanguageCode not found. Falling back to enUs.");
    return LanguageCode.enUs;
  }
}
