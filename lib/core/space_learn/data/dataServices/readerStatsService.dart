import 'package:http/http.dart' as http;
import '../model/readerStatsModel.dart';

class ReaderStatsService {
  final http.Client client;

  ReaderStatsService({http.Client? client}) : client = client ?? http.Client();

  // For now, return mock data since backend endpoint may not exist yet
  Future<ReaderStatsModel> getReaderStats(String userId) async {
    // TODO: Replace with actual API call when backend is ready
    // Example: final response = await client.get(Uri.parse('${ApiRoutes.analytics}?utilisateur_id=$userId'));

    // Mock data for demonstration
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay

    return ReaderStatsModel(booksRead: 12, totalTime: '34h', goalsAchieved: 5);
  }
}
