/*
 * Copyright (C) 2019-2025 HERE Europe B.V.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
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

package com.here.spatialaudionavigation;

import android.util.Log;

import com.here.sdk.core.LanguageCode;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

// Converts from com.here.sdk.core.LanguageCode to java.util.Locale and vice versa.
// Both language and country must be set, if available.
public class LanguageCodeConverter {

    private static final String TAG = LanguageCodeConverter.class.getName();

    private  static HashMap<LanguageCode, Locale> languageCodeMap;

    public static Locale getLocale(LanguageCode languageCode) {
        if (languageCodeMap == null) {
            initLanguageCodeMap();
        }

        if (languageCodeMap.containsKey(languageCode)) {
            return languageCodeMap.get(languageCode);
        }

        // Should never happen, unless the languageCodeMap was not updated
        // to support the latest LanguageCodes from HERE SDK.
        Log.e(TAG, "LanguageCode not found. Falling Back to en-US.");
        return new Locale("en", "US");
    }

    public static LanguageCode getLanguageCode(Locale locale) {
        if (languageCodeMap == null) {
            initLanguageCodeMap();
        }

        String language = locale.getLanguage();
        String country = locale.getCountry();

        for (Map.Entry<LanguageCode, Locale> languageCodeLocaleEntry : languageCodeMap.entrySet()) {
            Locale localeEntry = (Locale) ((Map.Entry) languageCodeLocaleEntry).getValue();

            String languageEntry = localeEntry.getLanguage();
            String countryEntry = localeEntry.getCountry();

            if (country == null) {
                if (language.equals(languageEntry)) {
                    return (LanguageCode) ((Map.Entry) languageCodeLocaleEntry).getKey();
                }
            } else {
                if (language.equals(languageEntry) && country.equals(countryEntry)) {
                    return (LanguageCode) ((Map.Entry) languageCodeLocaleEntry).getKey();
                }
            }
        }

        Log.e(TAG, "LanguageCode not found. Falling back to EN_US.");
        return LanguageCode.EN_US;
    }

    // / Language is always set, country may not be set.
    private static void initLanguageCodeMap() {
        languageCodeMap = new HashMap<>();

        /// English (United States)
        languageCodeMap.put(LanguageCode.EN_US, new Locale("en", "US"));

        /// Afrikaans
        languageCodeMap.put(LanguageCode.AF_ZA, new Locale("af", "ZA"));

        /// Albanian
        languageCodeMap.put(LanguageCode.SQ_AL, new Locale("sq", "AL"));

        /// Amharic (Ethiopia)
        languageCodeMap.put(LanguageCode.AM_ET, new Locale("am", "ET"));

        /// Arabic (Saudi Arabia)
        languageCodeMap.put(LanguageCode.AR_SA, new Locale("ar", "SA"));

        /// Armenian
        languageCodeMap.put(LanguageCode.HY_AM, new Locale("hy", "AM"));

        /// Assamese (India)
        languageCodeMap.put(LanguageCode.AS_IN, new Locale("as", "IN"));

        /// Azeri - Latin
        languageCodeMap.put(LanguageCode.AZ_LATN_AZ, new Locale("az", "LATN_AZ"));

        /// Bangla (Bangladesh)
        languageCodeMap.put(LanguageCode.BN_BD, new Locale("bn", "BD"));

        /// Bangla (India)
        languageCodeMap.put(LanguageCode.BN_IN, new Locale("bn", "IN"));

        /// Basque
        languageCodeMap.put(LanguageCode.EU_ES, new Locale("eu", "ES"));

        /// Belarusian
        languageCodeMap.put(LanguageCode.BE_BY, new Locale("be", "BY"));

        /// Bosnian - Latin
        languageCodeMap.put(LanguageCode.BS_LATN_BA, new Locale("bs", "LATN_BA"));

        /// Bulgarian
        languageCodeMap.put(LanguageCode.BG_BG, new Locale("bg", "BG"));

        /// Catalan (Spain)
        languageCodeMap.put(LanguageCode.CA_ES, new Locale("ca", "ES"));

        /// Central Kurdish - Arabic
        languageCodeMap.put(LanguageCode.KU_ARAB, new Locale("ku", "ARAB"));

        /// Chinese (Simplified China)
        languageCodeMap.put(LanguageCode.ZH_CN, new Locale("zh", "CN"));

        /// Chinese (Traditional Hong Kong)
        languageCodeMap.put(LanguageCode.ZH_HK, new Locale("zh", "HK"));

        /// Chinese (Traditional Taiwan)
        languageCodeMap.put(LanguageCode.ZH_TW, new Locale("zh", "TW"));

        /// Croatian
        languageCodeMap.put(LanguageCode.HR_HR, new Locale("hr", "HR"));

        /// Czech
        languageCodeMap.put(LanguageCode.CS_CZ, new Locale("cs", "CZ"));

        /// Danish
        languageCodeMap.put(LanguageCode.DA_DK, new Locale("da", "DK"));

        /// Dari - Arabic (Afghanistan)
        languageCodeMap.put(LanguageCode.PRS_ARAB_AF, new Locale("prs", "ARAB_AF"));

        /// Dutch
        languageCodeMap.put(LanguageCode.NL_NL, new Locale("nl", "NL"));

        /// English (British)
        languageCodeMap.put(LanguageCode.EN_GB, new Locale("en", "GB"));

        /// Estonian
        languageCodeMap.put(LanguageCode.ET_EE, new Locale("et", "EE"));

        /// Farsi (Iran)
        languageCodeMap.put(LanguageCode.FA_IR, new Locale("fa", "IR"));

        /// Filipino
        languageCodeMap.put(LanguageCode.FIL_PH, new Locale("fil", "PH"));

        /// Finnish
        languageCodeMap.put(LanguageCode.FI_FI, new Locale("fi", "FI"));

        /// French
        languageCodeMap.put(LanguageCode.FR_FR, new Locale("fr", "FR"));

        /// French (Canada)
        languageCodeMap.put(LanguageCode.FR_CA, new Locale("fr", "CA"));

        /// Galician
        languageCodeMap.put(LanguageCode.GL_ES, new Locale("gl", "ES"));

        /// Georgian
        languageCodeMap.put(LanguageCode.KA_GE, new Locale("ka", "GE"));

        /// German
        languageCodeMap.put(LanguageCode.DE_DE, new Locale("de", "DE"));

        /// Greek
        languageCodeMap.put(LanguageCode.EL_GR, new Locale("el", "GR"));

        /// Gujarati (India)
        languageCodeMap.put(LanguageCode.GU_IN, new Locale("gu", "IN"));

        /// Hausa - Latin (Nigeria)
        languageCodeMap.put(LanguageCode.HA_LATN_NG, new Locale("ha", "LATN_NG"));

        /// Hebrew
        languageCodeMap.put(LanguageCode.HE_IL, new Locale("he", "IL"));

        /// Hindi
        languageCodeMap.put(LanguageCode.HI_IN, new Locale("hi", "IN"));

        /// Hungarian
        languageCodeMap.put(LanguageCode.HU_HU, new Locale("hu", "HU"));

        /// Icelandic
        languageCodeMap.put(LanguageCode.IS_IS, new Locale("is", "IS"));

        /// Igbo - Latin (Nigera)
        languageCodeMap.put(LanguageCode.IG_LATN_NG, new Locale("ig", "LATN_NG"));

        /// Indonesian (Bahasa)
        languageCodeMap.put(LanguageCode.ID_ID, new Locale("id", "ID"));

        /// Irish
        languageCodeMap.put(LanguageCode.GA_IE, new Locale("ga", "IE"));

        /// IsiXhosa
        languageCodeMap.put(LanguageCode.XH, new Locale("xh"));

        /// IsiZulu (South Africa)
        languageCodeMap.put(LanguageCode.ZU_ZA, new Locale("zu", "ZA"));

        /// Italian
        languageCodeMap.put(LanguageCode.IT_IT, new Locale("it", "IT"));

        /// Japanese
        languageCodeMap.put(LanguageCode.JA_JP, new Locale("ja", "JP"));

        /// Kannada (India)
        languageCodeMap.put(LanguageCode.KN_IN, new Locale("kn", "IN"));

        /// Kazakh
        languageCodeMap.put(LanguageCode.KK_KZ, new Locale("kk", "KZ"));

        /// Khmer (Cambodia)
        languageCodeMap.put(LanguageCode.KM_KH, new Locale("km", "KH"));

        /// K'iche' - Latin (Guatemala)
        languageCodeMap.put(LanguageCode.QUC_LATN_GT, new Locale("quc", "LATN_GT"));

        /// Kinyarwanda (Rwanda)
        languageCodeMap.put(LanguageCode.RW_RW, new Locale("rw", "RW"));

        /// KiSwahili
        languageCodeMap.put(LanguageCode.SW, new Locale("sw"));

        /// Konkani (India)
        languageCodeMap.put(LanguageCode.KOK_IN, new Locale("kok", "IN"));

        /// Korean
        languageCodeMap.put(LanguageCode.KO_KR, new Locale("ko", "KR"));

        /// Kyrgyz - Cyrillic
        languageCodeMap.put(LanguageCode.KY_CYRL_KG, new Locale("ky", "CYRL_KG"));

        /// Latvian
        languageCodeMap.put(LanguageCode.LV_LV, new Locale("lv", "LV"));

        /// Lithuanian
        languageCodeMap.put(LanguageCode.LT_LT, new Locale("lt", "LT"));

        /// Luxembourgish
        languageCodeMap.put(LanguageCode.LB_LU, new Locale("lb", "LU"));

        /// Macedonian
        languageCodeMap.put(LanguageCode.MK_MK, new Locale("mk", "MK"));

        /// Malay (Bahasa)
        languageCodeMap.put(LanguageCode.MS_MY, new Locale("ms", "MY"));

        /// Malayalam (India)
        languageCodeMap.put(LanguageCode.ML_IN, new Locale("ml", "IN"));

        /// Maltese  (Malta)
        languageCodeMap.put(LanguageCode.MT_MT, new Locale("mt", "MT"));

        /// Maori - Latin (New Zealand)
        languageCodeMap.put(LanguageCode.MI_LATN_NZ, new Locale("mi", "LATN_NZ"));

        /// Marathi (India)
        languageCodeMap.put(LanguageCode.MR_IN, new Locale("mr", "IN"));

        /// Mongolian - Cyrillic
        languageCodeMap.put(LanguageCode.MN_CYRL_MN, new Locale("mn", "CYRL_MN"));

        /// Nepali (Nepal)
        languageCodeMap.put(LanguageCode.NE_NP, new Locale("ne", "NP"));

        /// Norwegian (Bokmål)
        languageCodeMap.put(LanguageCode.NB_NO, new Locale("nb", "NO"));

        /// Norwegian (Nynorsk)
        languageCodeMap.put(LanguageCode.NN_NO, new Locale("nn", "NO"));

        /// Odia (India)
        languageCodeMap.put(LanguageCode.OR_IN, new Locale("or", "IN"));

        /// Polish
        languageCodeMap.put(LanguageCode.PL_PL, new Locale("pl", "PL"));

        /// Portuguese (Brazil)
        languageCodeMap.put(LanguageCode.PT_BR, new Locale("pt", "BR"));

        /// Portuguese (Portugal)
        languageCodeMap.put(LanguageCode.PT_PT, new Locale("pt", "PT"));

        /// Punjabi - Gurmukhi
        languageCodeMap.put(LanguageCode.PA_GURU, new Locale("pa", "GURU"));

        /// Punjabi - Arabic
        languageCodeMap.put(LanguageCode.PA_ARAB, new Locale("pa", "ARAB"));

        /// Quechua - Latin (Peru)
        languageCodeMap.put(LanguageCode.QU_LATN_PE, new Locale("qu", "LATN_PE"));

        /// Romanian
        languageCodeMap.put(LanguageCode.RO_RO, new Locale("ro", "RO"));

        /// Russian
        languageCodeMap.put(LanguageCode.RU_RU, new Locale("ru", "RU"));

        /// Scottish Gaelic - Latin
        languageCodeMap.put(LanguageCode.GD_LATN_GB, new Locale("gd", "LATN_GB"));

        /// Serbian - Cyrillic (Bosnia)
        languageCodeMap.put(LanguageCode.SR_CYRL_BA, new Locale("sr", "CYRL_BA"));

        /// Serbian - Cyrillic (Serbia)
        languageCodeMap.put(LanguageCode.SR_CYRL_RS, new Locale("sr", "CYRL_RS"));

        /// Serbian - Latin (Serbia)
        languageCodeMap.put(LanguageCode.SR_LATN_RS, new Locale("sr", "LATN_RS"));

        /// Sesotho Sa Leboa (South Africa)
        languageCodeMap.put(LanguageCode.NSO_ZA, new Locale("nso", "ZA"));

        /// Setswana
        languageCodeMap.put(LanguageCode.TN, new Locale("tn"));

        /// Sindhi - Arabic
        languageCodeMap.put(LanguageCode.SD_ARAB, new Locale("sd", "ARAB"));

        /// Sinhala (Sri Lanka)
        languageCodeMap.put(LanguageCode.SI_LK, new Locale("si", "LK"));

        /// Slovak
        languageCodeMap.put(LanguageCode.SK_SK, new Locale("sk", "SK"));

        /// Slovenian
        languageCodeMap.put(LanguageCode.SL_SI, new Locale("sl", "SI"));

        /// Spanish (Mexico)
        languageCodeMap.put(LanguageCode.ES_MX, new Locale("es", "MX"));

        /// Spanish (Spain)
        languageCodeMap.put(LanguageCode.ES_ES, new Locale("es", "ES"));

        /// Swedish
        languageCodeMap.put(LanguageCode.SV_SE, new Locale("sv", "SE"));

        /// Tajik - Cyrillic
        languageCodeMap.put(LanguageCode.TG_CYRL_TJ, new Locale("tg", "CYRL_TJ"));

        /// Tamil
        languageCodeMap.put(LanguageCode.TA, new Locale("ta"));

        /// Tatar - Cyrillic (Russia)
        languageCodeMap.put(LanguageCode.TT_CYRL_RU, new Locale("tt", "CYRL_RU"));

        /// Telugu (India)
        languageCodeMap.put(LanguageCode.TE_IN, new Locale("te", "IN"));

        /// Thai
        languageCodeMap.put(LanguageCode.TH_TH, new Locale("th", "TH"));

        /// Tigrinya (Ethiopia)
        languageCodeMap.put(LanguageCode.TI_ET, new Locale("ti", "ET"));

        /// Turkish
        languageCodeMap.put(LanguageCode.TR_TR, new Locale("tr", "TR"));

        /// Turkmen - Latin
        languageCodeMap.put(LanguageCode.TK_LATN_TM, new Locale("tk", "LATN_TM"));

        /// Ukrainian
        languageCodeMap.put(LanguageCode.UK_UA, new Locale("uk", "UA"));

        /// Urdu
        languageCodeMap.put(LanguageCode.UR, new Locale("ur"));

        /// Uyghur - Arabic
        languageCodeMap.put(LanguageCode.UG_ARAB, new Locale("ug", "ARAB"));

        /// Uzbek - Cyrillic
        languageCodeMap.put(LanguageCode.UZ_CYRL_UZ, new Locale("uz", "CYRL_UZ"));

        /// Uzbek - Latin
        languageCodeMap.put(LanguageCode.UZ_LATN_UZ, new Locale("uz", "LATN_UZ"));

        /// Valencian (Spain)
        languageCodeMap.put(LanguageCode.CAT_ES, new Locale("cat", "ES"));

        /// Vietnamese
        languageCodeMap.put(LanguageCode.VI_VN, new Locale("vi", "VN"));

        /// Welsh
        languageCodeMap.put(LanguageCode.CY_GB, new Locale("cy", "GB"));

        /// Wolof - Latin
        languageCodeMap.put(LanguageCode.WO_LATN, new Locale("wo", "LATN"));

        /// Yoruba - Latin
        languageCodeMap.put(LanguageCode.YO_LATN, new Locale("yo", "LATN"));
    }
}
