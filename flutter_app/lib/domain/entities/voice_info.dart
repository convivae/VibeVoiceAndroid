/// Voice information for the voice selector.
/// Maps to the VoiceInfo Pydantic model from /voices endpoint.
class VoiceInfo {
  /// Unique voice identifier.
  final String id;

  /// Display name for the voice.
  final String name;

  /// Language code: "zh" (Mandarin), "en" (English), "mixed" (bilingual).
  final String language;

  /// Gender: "female", "male", "neutral".
  final String gender;

  const VoiceInfo({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
  });

  /// Parse from server JSON response.
  factory VoiceInfo.fromJson(Map<String, dynamic> json) {
    return VoiceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      language: json['language'] as String,
      gender: json['gender'] as String,
    );
  }

  /// Default preset voices (matching server-side PRESET_VOICES per D-04).
  /// 2 Chinese + 2 English + 1 mixed.
  static const List<VoiceInfo> defaultVoices = [
    VoiceInfo(id: 'zh_female_1', name: '中文女声-温柔', language: 'zh', gender: 'female'),
    VoiceInfo(id: 'zh_male_1', name: '中文男声-稳重', language: 'zh', gender: 'male'),
    VoiceInfo(id: 'en_female_1', name: 'English Female', language: 'en', gender: 'female'),
    VoiceInfo(id: 'en_male_1', name: 'English Male', language: 'en', gender: 'male'),
    VoiceInfo(id: 'mixed_1', name: '中英混合', language: 'mixed', gender: 'neutral'),
  ];
}
