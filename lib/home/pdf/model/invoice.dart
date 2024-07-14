class Invoice {
  final List<InvoiceItem> items;

  const Invoice({
    required this.items,
  });
}

class InvoiceItem {
  final int id;
  final String date;
  final double temperature;
  final double humidity;
  final double pression;

  const InvoiceItem({
    required this.id,
    required this.date,
    required this.temperature,
    required this.humidity,
    required this.pression,
  });
}
