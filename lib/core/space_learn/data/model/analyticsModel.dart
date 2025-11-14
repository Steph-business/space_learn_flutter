class AnalyticsData {
  final double totalRevenue;
  final int totalViews;
  final int totalDownloads;
  final double averageRating;
  final double conversionRate;
  final int newReaders;
  final double satisfactionRate;
  final double averageReadingTime;
  final double recurringReadersRate;
  final double revenuePerView;
  final int newSubscribers;
  final int commentsReceived;
  final List<double> revenueChartData;
  final List<String> chartLabels;

  AnalyticsData({
    required this.totalRevenue,
    required this.totalViews,
    required this.totalDownloads,
    required this.averageRating,
    required this.conversionRate,
    required this.newReaders,
    required this.satisfactionRate,
    required this.averageReadingTime,
    required this.recurringReadersRate,
    required this.revenuePerView,
    required this.newSubscribers,
    required this.commentsReceived,
    required this.revenueChartData,
    required this.chartLabels,
  });

  factory AnalyticsData.empty() {
    return AnalyticsData(
      totalRevenue: 0.0,
      totalViews: 0,
      totalDownloads: 0,
      averageRating: 0.0,
      conversionRate: 0.0,
      newReaders: 0,
      satisfactionRate: 0.0,
      averageReadingTime: 0.0,
      recurringReadersRate: 0.0,
      revenuePerView: 0.0,
      newSubscribers: 0,
      commentsReceived: 0,
      revenueChartData: [],
      chartLabels: [],
    );
  }

  // Mock data generator for different time periods
  factory AnalyticsData.generateMockData(String period) {
    switch (period) {
      case '7 jours':
        return AnalyticsData(
          totalRevenue: 1285.0,
          totalViews: 15247,
          totalDownloads: 3456,
          averageRating: 4.7,
          conversionRate: 2.3,
          newReaders: 156,
          satisfactionRate: 89.0,
          averageReadingTime: 4.2,
          recurringReadersRate: 67.0,
          revenuePerView: 0.37,
          newSubscribers: 23,
          commentsReceived: 47,
          revenueChartData: [3.0, 5.5, 4.0, 7.0, 6.0, 8.0, 7.5],
          chartLabels: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
        );
      case '30 jours':
        return AnalyticsData(
          totalRevenue: 4850.0,
          totalViews: 58750,
          totalDownloads: 12450,
          averageRating: 4.6,
          conversionRate: 2.8,
          newReaders: 623,
          satisfactionRate: 87.0,
          averageReadingTime: 4.5,
          recurringReadersRate: 72.0,
          revenuePerView: 0.42,
          newSubscribers: 89,
          commentsReceived: 156,
          revenueChartData: [12.0, 15.5, 14.0, 17.0, 16.0, 18.0, 17.5, 15.0],
          chartLabels: ['S1', 'S2', 'S3', 'S4'],
        );
      case '3 mois':
        return AnalyticsData(
          totalRevenue: 15200.0,
          totalViews: 185000,
          totalDownloads: 38750,
          averageRating: 4.5,
          conversionRate: 3.2,
          newReaders: 1856,
          satisfactionRate: 85.0,
          averageReadingTime: 4.8,
          recurringReadersRate: 75.0,
          revenuePerView: 0.45,
          newSubscribers: 267,
          commentsReceived: 423,
          revenueChartData: [
            45.0,
            52.5,
            48.0,
            55.0,
            50.0,
            58.0,
            56.5,
            52.0,
            48.0,
            55.0,
            50.0,
            58.0,
          ],
          chartLabels: ['M1', 'M2', 'M3'],
        );
      case '1 an':
        return AnalyticsData(
          totalRevenue: 58750.0,
          totalViews: 725000,
          totalDownloads: 152500,
          averageRating: 4.4,
          conversionRate: 3.8,
          newReaders: 7256,
          satisfactionRate: 82.0,
          averageReadingTime: 5.2,
          recurringReadersRate: 78.0,
          revenuePerView: 0.48,
          newSubscribers: 1256,
          commentsReceived: 1856,
          revenueChartData: [
            180.0,
            195.5,
            185.0,
            210.0,
            205.0,
            225.0,
            220.5,
            215.0,
            200.0,
            218.0,
            210.0,
            230.0,
          ],
          chartLabels: [
            'Jan',
            'Fév',
            'Mar',
            'Avr',
            'Mai',
            'Jun',
            'Jul',
            'Aoû',
            'Sep',
            'Oct',
            'Nov',
            'Déc',
          ],
        );
      default:
        return AnalyticsData.empty();
    }
  }
}
