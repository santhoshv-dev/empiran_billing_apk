import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

String amountInWords(double value) {
  const one = [
    '',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  const tens = [
    '',
    '',
    'Twenty',
    'Thirty',
    'Forty',
    'Fifty',
    'Sixty',
    'Seventy',
    'Eighty',
    'Ninety',
  ];
  String under100(int n) =>
      n < 20 ? one[n] : '${tens[n ~/ 10]} ${one[n % 10]}'.trim();
  String under1000(int n) => n < 100
      ? under100(n)
      : '${one[n ~/ 100]} Hundred${n % 100 == 0 ? '' : ' ${under100(n % 100)}'}';
  String say(int n) {
    if (n == 0) return 'Zero';
    final parts = <String>[];
    for (final x in [
      (10000000, 'Crore'),
      (100000, 'Lakh'),
      (1000, 'Thousand'),
    ]) {
      if (n >= x.$1) {
        parts.add('${under1000(n ~/ x.$1)} ${x.$2}');
        n %= x.$1;
      }
    }
    if (n > 0) parts.add(under1000(n));
    return parts.join(' ');
  }

  final rupees = value.floor(), paise = ((value - rupees) * 100).round();
  return 'INR ${say(rupees)}${paise > 0 ? ' and ${say(paise)} Paise' : ''} Only';
}

pw.Widget _cell(
  String value, {
  bool bold = false,
  pw.Alignment align = pw.Alignment.centerLeft,
  double pad = 3,
}) => pw.Container(
  alignment: align,
  padding: pw.EdgeInsets.all(pad),
  child: pw.Text(
    value,
    style: pw.TextStyle(
      fontSize: 7,
      fontWeight: bold ? pw.FontWeight.bold : null,
    ),
  ),
);

Future<Uint8List> buildInvoicePdf(Company c, BusinessTransaction t) async {
  final doc = pw.Document();
  final fmt = NumberFormat.currency(locale: 'en_IN', symbol: 'INR ');
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(22),
      build: (_) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              '(ORIGINAL FOR RECIPIENT)',
              style: const pw.TextStyle(fontSize: 7),
            ),
          ],
        ),
        pw.Center(
          child: pw.Text(
            t.isGst ? 'TAX INVOICE' : 'INVOICE',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(width: .6),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        c.name,
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        c.address,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'GSTIN/UIN: ${c.gstin}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'State: ${c.state}, Code: ${c.stateCode}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                      pw.Text(
                        'Contact: ${c.phone}   ${c.email}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ],
                  ),
                ),
                pw.Table(
                  border: pw.TableBorder.all(width: .35),
                  children: [
                    for (final row in [
                      [
                        'Invoice No.',
                        '${t.number}',
                        'Dated',
                        DateFormat('dd-MMM-yyyy').format(t.date),
                      ],
                      [
                        'Delivery Note',
                        t.dispatch['deliveryNote'] ?? '',
                        'Mode/Terms of Payment',
                        t.dispatch['paymentMode'] ?? t.paymentMode,
                      ],
                      [
                        'Reference No & Date',
                        t.dispatch['reference'] ?? '',
                        'Other References',
                        t.dispatch['otherReferences'] ?? '',
                      ],
                      [
                        "Buyer's Order No",
                        t.dispatch['buyersOrderNo'] ?? '',
                        'Dated',
                        t.dispatch['buyersOrderDate'] ?? '',
                      ],
                      [
                        'Dispatch Doc No',
                        t.dispatch['dispatchDocNo'] ?? '',
                        'Delivery Note Date',
                        t.dispatch['deliveryNoteDate'] ?? '',
                      ],
                      [
                        'Dispatched Through',
                        t.dispatch['transportMode'] ?? '',
                        'Destination',
                        t.dispatch['destination'] ?? '',
                      ],
                      [
                        'Bill of Lading / LR-RR No',
                        t.dispatch['lrNo'] ?? '',
                        'Motor Vehicle No',
                        t.dispatch['vehicleNo'] ?? '',
                      ],
                    ])
                      pw.TableRow(children: row.map((x) => _cell(x)).toList()),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Buyer (Bill to)',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                t.partyName.isEmpty ? 'Cash Customer' : t.partyName,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (t.partyAddress.isNotEmpty)
                pw.Text(t.partyAddress, style: const pw.TextStyle(fontSize: 8)),
              if (t.partyGstin.isNotEmpty)
                pw.Text(
                  'GSTIN/UIN: ${t.partyGstin}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: .5),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(52),
            3: const pw.FixedColumnWidth(52),
            4: const pw.FixedColumnWidth(35),
            5: const pw.FixedColumnWidth(70),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children:
                  [
                        'Sl No',
                        'Description of Goods',
                        'Quantity',
                        'Rate',
                        'per',
                        'Amount',
                      ]
                      .map(
                        (x) => _cell(x, bold: true, align: pw.Alignment.center),
                      )
                      .toList(),
            ),
            for (int i = 0; i < t.lines.length; i++)
              pw.TableRow(
                children: [
                  _cell('${i + 1}', align: pw.Alignment.center),
                  _cell(
                    '${t.lines[i].name}${t.lines[i].hsn.isEmpty ? '' : '\nHSN: ${t.lines[i].hsn}'}',
                    bold: true,
                  ),
                  _cell(
                    '${t.lines[i].quantity} ${t.lines[i].unit}',
                    align: pw.Alignment.centerRight,
                  ),
                  _cell(
                    t.lines[i].price.toStringAsFixed(2),
                    align: pw.Alignment.centerRight,
                  ),
                  _cell(t.lines[i].unit, align: pw.Alignment.center),
                  _cell(
                    t.lines[i].total.toStringAsFixed(2),
                    align: pw.Alignment.centerRight,
                  ),
                ],
              ),
            if (t.isGst)
              pw.TableRow(
                children: [
                  _cell(''),
                  _cell('C.G.S.T. @ 9%', bold: true),
                  _cell(''),
                  _cell('9%'),
                  _cell(''),
                  _cell(
                    t.cgst.toStringAsFixed(2),
                    align: pw.Alignment.centerRight,
                  ),
                ],
              ),
            if (t.isGst)
              pw.TableRow(
                children: [
                  _cell(''),
                  _cell('S.G.S.T. @ 9%', bold: true),
                  _cell(''),
                  _cell('9%'),
                  _cell(''),
                  _cell(
                    t.sgst.toStringAsFixed(2),
                    align: pw.Alignment.centerRight,
                  ),
                ],
              ),
            pw.TableRow(
              children: [
                _cell(''),
                _cell('Total', bold: true),
                _cell(
                  '${t.lines.fold<double>(0, (a, b) => a + b.quantity)} Pcs',
                  bold: true,
                  align: pw.Alignment.centerRight,
                ),
                _cell(''),
                _cell(''),
                _cell(
                  fmt.format(t.total),
                  bold: true,
                  align: pw.Alignment.centerRight,
                ),
              ],
            ),
          ],
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: .6)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Amount Chargeable (in words)',
                style: const pw.TextStyle(fontSize: 7),
              ),
              pw.Text(
                amountInWords(t.total),
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: .6),
          columnWidths: {
            0: const pw.FlexColumnWidth(),
            1: const pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Declaration',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                    ],
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(7),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Company Bank Details',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Bank: ${c.bankName}\nA/c No: ${c.accountNo}\nBranch & IFSC: ${c.branch}, ${c.ifsc}',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.SizedBox(height: 18),
                      pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          'for ${c.name}\n\nAuthorized Signatory',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'This is a Computer Generated Invoice',
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
      ],
    ),
  );
  return doc.save();
}
