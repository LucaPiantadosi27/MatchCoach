enum AnalysisStatus { pending, processing, done, error, cancelled }

class MatchVideoModel {
  final String id;
  final String matchId;
  final String userId;
  final int sequenceOrder;
  final String videoName;
  final String? geminiFileUri;
  final Map<String, dynamic>? analysisJson;
  final AnalysisStatus analysisStatus;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String? modelName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MatchVideoModel({
    required this.id,
    required this.matchId,
    required this.userId,
    required this.sequenceOrder,
    required this.videoName,
    this.geminiFileUri,
    this.analysisJson,
    this.analysisStatus = AnalysisStatus.pending,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.modelName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAnalyzed => analysisStatus == AnalysisStatus.done;
  bool get isProcessing => analysisStatus == AnalysisStatus.processing;

  factory MatchVideoModel.fromJson(Map<String, dynamic> json) => MatchVideoModel(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        userId: json['user_id'] as String,
        sequenceOrder: json['sequence_order'] as int? ?? 0,
        videoName: json['video_name'] as String,
        geminiFileUri: json['gemini_file_uri'] as String?,
        analysisJson: json['analysis_json'] as Map<String, dynamic>?,
        analysisStatus: _parseStatus(json['analysis_status'] as String? ?? 'pending'),
        promptTokens: json['prompt_tokens'] as int? ?? 0,
        completionTokens: json['completion_tokens'] as int? ?? 0,
        totalTokens: json['total_tokens'] as int? ?? 0,
        modelName: json['model_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  static AnalysisStatus _parseStatus(String s) {
    switch (s) {
      case 'processing': return AnalysisStatus.processing;
      case 'done': return AnalysisStatus.done;
      case 'error': return AnalysisStatus.error;
      case 'cancelled': return AnalysisStatus.cancelled;
      default: return AnalysisStatus.pending;
    }
  }

  Map<String, dynamic> toInsertJson(String userId) => {
        'match_id': matchId,
        'user_id': userId,
        'sequence_order': sequenceOrder,
        'video_name': videoName,
        if (geminiFileUri != null) 'gemini_file_uri': geminiFileUri,
        'analysis_status': analysisStatus.name,
      };

  MatchVideoModel copyWith({
    AnalysisStatus? analysisStatus,
    Map<String, dynamic>? analysisJson,
    String? geminiFileUri,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? modelName,
  }) =>
      MatchVideoModel(
        id: id,
        matchId: matchId,
        userId: userId,
        sequenceOrder: sequenceOrder,
        videoName: videoName,
        geminiFileUri: geminiFileUri ?? this.geminiFileUri,
        analysisJson: analysisJson ?? this.analysisJson,
        analysisStatus: analysisStatus ?? this.analysisStatus,
        promptTokens: promptTokens ?? this.promptTokens,
        completionTokens: completionTokens ?? this.completionTokens,
        totalTokens: totalTokens ?? this.totalTokens,
        modelName: modelName ?? this.modelName,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
