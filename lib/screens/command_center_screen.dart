import 'package:flutter/material.dart';

class CommandCenterScreen extends StatelessWidget {
  const CommandCenterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Command Center'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          Container(
            width: 250,
            color: Colors.blueGrey[800],
            child: ListView(
              children: const [
                ListTile(title: Text('Overview', style: TextStyle(color: Colors.white)), leading: Icon(Icons.dashboard, color: Colors.white)),
                ListTile(title: Text('Financials (MoMo/Orange)', style: TextStyle(color: Colors.white)), leading: Icon(Icons.account_balance_wallet, color: Colors.white)),
                ListTile(title: Text('Academic Health', style: TextStyle(color: Colors.white)), leading: Icon(Icons.analytics, color: Colors.white)),
                ListTile(title: Text('Attendance Register', style: TextStyle(color: Colors.white)), leading: Icon(Icons.rule, color: Colors.white)),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Real-time KPIs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _kpiCard('Active Students', '1,432', Colors.blue),
                      _kpiCard('Fee Collection Sync', '94%', Colors.green),
                      _kpiCard('Sequence Completion', '82%', Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Financial Reconciliation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  _financialTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String val, Color color) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(side: BorderSide(color: color, width: 2), borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.only(right: 16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(val, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _financialTable() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!)),
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Transaction ID')),
              DataColumn(label: Text('Provider')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Status')),
            ],
            rows: const [
              DataRow(cells: [DataCell(Text('TXN-001')), DataCell(Text('MTN MoMo')), DataCell(Text('50,000 XAF')), DataCell(Text('Reconciled'))]),
              DataRow(cells: [DataCell(Text('TXN-002')), DataCell(Text('Orange Money')), DataCell(Text('75,000 XAF')), DataCell(Text('Pending'))]),
              DataRow(cells: [DataCell(Text('TXN-003')), DataCell(Text('MTN MoMo')), DataCell(Text('25,000 XAF')), DataCell(Text('Reconciled'))]),
            ],
          ),
        ),
      ),
    );
  }
}
