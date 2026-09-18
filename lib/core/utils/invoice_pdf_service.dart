import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models.dart';

String reportCsv(List<BusinessTransaction> rows) {
  String cell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
  return [
    [
      'Date',
      'Number',
      'Type',
      'Party',
      'Subtotal',
      'Tax',
      'Total',
      'Paid',
      'Balance',
      'Payment mode',
      'Status',
    ],
    for (final t in rows)
      [
        DateFormat('yyyy-MM-dd').format(t.date),
        t.number,
        t.type,
        t.partyName,
        t.subtotal,
        t.cgst + t.sgst,
        t.total,
        t.paid,
        t.balance,
        t.paymentMode,
        t.status,
      ],
  ].map((row) => row.map(cell).join(',')).join('\r\n');
}

Future<Uint8List> buildReportPdf(
  Company company,
  List<BusinessTransaction> rows,
  String title,
) async {
  final doc = pw.Document();
  String money(double n) =>
      NumberFormat.currency(locale: 'en_IN', symbol: 'INR ').format(n);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (_) => [
        pw.Text(
          company.displayName,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(title),
        pw.SizedBox(height: 16),
        pw.Text(
          'Records: ${rows.length}    Total: ${money(rows.fold(0, (s, t) => s + t.total))}    Paid: ${money(rows.fold(0, (s, t) => s + t.paid))}    Balance: ${money(rows.fold(0, (s, t) => s + t.balance))}',
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: [
            'Date',
            'Number',
            'Party',
            'Type',
            'Total',
            'Paid',
            'Balance',
            'Status',
          ],
          data: [
            for (final t in rows)
              [
                DateFormat.yMd().format(t.date),
                t.number,
                t.partyName,
                t.type,
                money(t.total),
                money(t.paid),
                money(t.balance),
                t.status,
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

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

Future<Uint8List> buildInvoicePdf(
  Company c,
  BusinessTransaction t, {
  InvoiceSettings? settings,
}) async {
  final design = settings ?? InvoiceSettings();
  final accent = PdfColor.fromInt(design.accentColor);
  final isModern = design.template == 'modern';
  final isCompact = design.template == 'compact';
  final defaultTitle = t.type == 'quotation' || t.type == 'estimate'
      ? 'Quotation'
      : t.type == 'delivery_note'
          ? 'Delivery Note'
          : t.type == 'order'
              ? 'Order / Tax Invoice'
              : 'Tax Invoice';
  final documentTitle = design.customTitle.trim().isEmpty
      ? defaultTitle
      : design.customTitle.trim();
  final doc = pw.Document();
  pw.MemoryImage? logo;
  if (design.showLogo && c.logo != null && c.logo!.isNotEmpty) {
    try {
      logo = pw.MemoryImage(base64Decode(c.logo!.split(',').last));
    } catch (_) {
      /* Older backups may contain an image URL. */
    }
  }
  final pageMargin = isCompact ? 8.0 : (isModern ? 18.0 : 12.0);

  pw.Widget infoCell(String label, String value, {bool boldValue = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(3),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 6.5, color: PdfColors.grey700)),
            pw.SizedBox(height: 1),
            pw.Text(
              value.isNotEmpty ? value : '-',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: boldValue ? pw.FontWeight.bold : null,
              ),
            ),
          ],
        ),
      );

  pw.Widget tblCell(
    String text, {
    bool bold = false,
    pw.Alignment align = pw.Alignment.centerLeft,
    double pad = 3.5,
    PdfColor? color,
  }) =>
      pw.Container(
        alignment: align,
        padding: pw.EdgeInsets.all(pad),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: isCompact ? 7.0 : 7.5,
            fontWeight: bold ? pw.FontWeight.bold : null,
            color: color,
          ),
        ),
      );

  final totalQty = t.lines.fold<double>(0, (a, b) => a + b.quantity);
  final totalQtyFormatted = totalQty == totalQty.roundToDouble()
      ? totalQty.toStringAsFixed(0)
      : totalQty.toStringAsFixed(2);
  final taxableVal = (t.subtotal - t.discount).clamp(0, double.infinity);
  final double fillerHeight = ((isCompact ? 150.0 : (t.isGst ? 220.0 : 260.0)) -
          (t.lines.length * 20.0) -
          (t.discount > 0 ? 14.0 : 0.0))
      .clamp(10.0, 220.0);

  pw.ThemeData? theme;
  try {
    final fontNormal = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final fontItalic = await PdfGoogleFonts.robotoItalic();
    theme = pw.ThemeData.withFont(
      base: fontNormal,
      bold: fontBold,
      italic: fontItalic,
    );
  } catch (_) {
    // Offline fallback to default Type1 Helvetica
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(pageMargin),
      theme: theme,
      build: (_) => [
        // 1. Top Header Area (Logo on left, ORIGINAL FOR RECIPIENT on right, Title centered)
        pw.Container(
          padding: const pw.EdgeInsets.fromLTRB(2, 2, 2, 5),
          decoration: isModern
              ? pw.BoxDecoration(
                  border:
                      pw.Border(bottom: pw.BorderSide(color: accent, width: 2)),
                )
              : null,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Image(logo, width: 90, height: 42, fit: pw.BoxFit.contain)
              else
                pw.Text(
                  c.displayName.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: accent),
                ),
              pw.Text(
                'ORIGINAL FOR RECIPIENT',
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                  color: isModern ? accent : null,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text(
            documentTitle,
            style: pw.TextStyle(
              fontSize: isModern ? 15 : 13,
              fontWeight: pw.FontWeight.bold,
              color: isModern ? accent : null,
            ),
          ),
        ),
        pw.SizedBox(height: 5),

        // 2. Main Box Container
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              width: isModern ? 1.1 : 0.8,
              color: isModern ? accent : PdfColors.black,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Top Details 2-Column Table
              pw.Table(
                border: const pw.TableBorder(bottom: pw.BorderSide(width: 0.6)),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.15),
                  1: const pw.FlexColumnWidth(1.0),
                },
                children: [
                  pw.TableRow(
                    children: [
                      // Left: Seller, Consignee, Buyer
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                        children: [
                          if (design.showSellerDetails) ...[
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(c.displayName.toUpperCase(),
                                      style: pw.TextStyle(
                                          fontSize: 9.5,
                                          color: isModern ? accent : null,
                                          fontWeight: pw.FontWeight.bold)),
                                  if (c.address.isNotEmpty)
                                    pw.Text(c.address,
                                        style:
                                            const pw.TextStyle(fontSize: 7.5)),
                                  if (c.state.isNotEmpty)
                                    pw.Text(
                                        '${c.state}${c.stateCode.isNotEmpty ? ' - ${c.stateCode}' : ''}',
                                        style:
                                            const pw.TextStyle(fontSize: 7.5)),
                                  if (c.gstin.isNotEmpty)
                                    pw.Text('GSTIN/UIN #: ${c.gstin}',
                                        style: pw.TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: pw.FontWeight.bold)),
                                  if (c.phone.isNotEmpty)
                                    pw.Text('Phone #: ${c.phone}',
                                        style:
                                            const pw.TextStyle(fontSize: 7.5)),
                                ],
                              ),
                            ),
                            pw.Container(height: 0.6, color: PdfColors.black),
                          ],
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Consignee (Ship to)',
                                    style: pw.TextStyle(
                                        fontSize: 6.5,
                                        fontStyle: pw.FontStyle.italic)),
                                pw.Text(
                                  t.dispatch['consigneeName'] ??
                                      (t.partyName.isNotEmpty
                                          ? t.partyName
                                          : 'ABM TRADERS'),
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  t.dispatch['consigneeAddress'] ??
                                      (t.partyAddress.isNotEmpty
                                          ? t.partyAddress
                                          : 'PARTY SITE'),
                                  style: const pw.TextStyle(fontSize: 7.5),
                                ),
                              ],
                            ),
                          ),
                          pw.Container(height: 0.6, color: PdfColors.black),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('Buyer (Bill to)',
                                    style: pw.TextStyle(
                                        fontSize: 6.5,
                                        fontStyle: pw.FontStyle.italic)),
                                pw.Text(
                                  t.partyName.isNotEmpty
                                      ? t.partyName
                                      : 'Cash Customer',
                                  style: pw.TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: pw.FontWeight.bold),
                                ),
                                if (t.partyAddress.isNotEmpty)
                                  pw.Text(t.partyAddress,
                                      style: const pw.TextStyle(fontSize: 7.5)),
                                if (t.partyGstin.isNotEmpty)
                                  pw.Text('GSTIN/UIN : ${t.partyGstin}',
                                      style: const pw.TextStyle(fontSize: 7.5)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Right: Dispatch and Invoice meta table
                      pw.Table(
                        border: const pw.TableBorder(
                          left: pw.BorderSide(width: 0.6),
                          horizontalInside: pw.BorderSide(width: 0.4),
                          verticalInside: pw.BorderSide(width: 0.4),
                        ),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1),
                          1: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(children: [
                            infoCell('Invoice No.', t.number, boldValue: true),
                            infoCell('Invoice Date',
                                DateFormat('dd/MM/yyyy').format(t.date)),
                          ]),
                          pw.TableRow(children: [
                            infoCell('Mode/Terms of Payment',
                                t.dispatch['paymentMode'] ?? t.paymentMode),
                            infoCell('Payment Due:',
                                DateFormat('dd/MM/yyyy').format(t.date)),
                          ]),
                          pw.TableRow(children: [
                            infoCell(
                                'DC.No.',
                                t.dispatch['deliveryNote'] ??
                                    t.dispatch['dcNo'] ??
                                    (t.dispatch['dispatchDocNo'] ?? '13039')),
                            infoCell(
                                'Other Reference(s)',
                                t.dispatch['reference'] ??
                                    t.dispatch['otherReferences'] ??
                                    ''),
                          ]),
                          pw.TableRow(children: [
                            infoCell('PO.Details',
                                t.dispatch['buyersOrderNo'] ?? ''),
                            infoCell(
                                'PO Date', t.dispatch['buyersOrderDate'] ?? ''),
                          ]),
                          pw.TableRow(children: [
                            infoCell(
                                'Driver', t.dispatch['transportMode'] ?? ''),
                            infoCell('Motor Vehicle No.',
                                t.dispatch['vehicleNo'] ?? 'TN 97 T 4401'),
                          ]),
                          pw.TableRow(children: [
                            infoCell('Terms of Delivery',
                                t.dispatch['destination'] ?? ''),
                            infoCell('Dispatch Doc No',
                                t.dispatch['dispatchDocNo'] ?? ''),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Products Table
              pw.Table(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(width: 0.6),
                  horizontalInside: pw.BorderSide(width: 0.4),
                  verticalInside: pw.BorderSide(width: 0.4),
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(),
                  2: const pw.FixedColumnWidth(54),
                  3: const pw.FixedColumnWidth(48),
                  4: const pw.FixedColumnWidth(54),
                  5: const pw.FixedColumnWidth(34),
                  6: const pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: isModern ? accent : PdfColors.grey100,
                    ),
                    children: [
                      tblCell('S.No',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('Description of Goods/Services',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('HSN/SAC',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('Quantity',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('Rate',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('UOM',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                      tblCell('Amount',
                          bold: true,
                          align: pw.Alignment.center,
                          color: isModern ? PdfColors.white : null),
                    ],
                  ),
                  for (int i = 0; i < t.lines.length; i++)
                    pw.TableRow(
                      children: [
                        tblCell('${i + 1}', align: pw.Alignment.center),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(3.5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(t.lines[i].name,
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(
                                  'Total Count : ${t.lines[i].quantity.toInt()}',
                                  style: const pw.TextStyle(
                                      fontSize: 6.5, color: PdfColors.grey700)),
                            ],
                          ),
                        ),
                        tblCell(
                            t.lines[i].hsn.isNotEmpty
                                ? t.lines[i].hsn
                                : '25171010',
                            align: pw.Alignment.center),
                        tblCell(
                          t.lines[i].quantity ==
                                  t.lines[i].quantity.roundToDouble()
                              ? t.lines[i].quantity.toStringAsFixed(0)
                              : t.lines[i].quantity.toStringAsFixed(2),
                          align: pw.Alignment.centerRight,
                        ),
                        tblCell('Rs. ${t.lines[i].price.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                        tblCell(t.lines[i].unit, align: pw.Alignment.center),
                        tblCell('Rs. ${t.lines[i].total.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                      ],
                    ),

                  // Filler row to maintain grid vertical lines
                  if (fillerHeight > 10.0)
                    pw.TableRow(
                      children: [
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                        pw.SizedBox(height: fillerHeight),
                      ],
                    ),

                  // Discount row (if any)
                  if (t.discount > 0)
                    pw.TableRow(
                      children: [
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('Discount:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5)),
                        ),
                        tblCell(''),
                        tblCell('-Rs. ${t.discount.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight, bold: true),
                      ],
                    ),

                  // Tax rows (aligned right under Rate and Amount)
                  if (t.isGst) ...[
                    pw.TableRow(
                      children: [
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('CGST 9%',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5)),
                        ),
                        tblCell(''),
                        tblCell('Rs. ${t.cgst.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight, bold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('SGST 9%',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5)),
                        ),
                        tblCell(''),
                        tblCell('Rs. ${t.sgst.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight, bold: true),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        tblCell(''),
                        pw.Container(
                          alignment: pw.Alignment.centerRight,
                          padding: const pw.EdgeInsets.all(3),
                          child: pw.Text('Round_off:',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 7.5)),
                        ),
                        tblCell(''),
                        tblCell('Rs. 0.00',
                            align: pw.Alignment.centerRight, bold: true),
                      ],
                    ),
                  ],

                  // Grand Total row
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      tblCell(''),
                      tblCell('Total', bold: true, align: pw.Alignment.center),
                      tblCell(''),
                      tblCell(totalQtyFormatted,
                          align: pw.Alignment.centerRight, bold: true),
                      tblCell(''),
                      tblCell(''),
                      tblCell('Rs. ${t.total.toStringAsFixed(2)}',
                          align: pw.Alignment.centerRight, bold: true),
                    ],
                  ),
                ],
              ),

              // Amount in Words and Payment Info
              pw.Container(
                decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (design.showAmountInWords)
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Amount in Words',
                              style: const pw.TextStyle(
                                  fontSize: 6.5, color: PdfColors.grey700)),
                          pw.Text(
                            amountInWords(t.total).replaceFirst('INR', 'Rupees'),
                            style: pw.TextStyle(
                                fontSize: 7.5, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      pw.SizedBox(),
                    if (t.type != 'quotation')
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Payment Method: ${t.paymentMode}',
                              style: pw.TextStyle(
                                  fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                          if (t.paid >= 0 && t.paid < t.total)
                            pw.Text('Balance Due: Rs. ${(t.total - t.paid).toStringAsFixed(2)}',
                                style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
              ),

              // HSN / SAC Tax Summary Table (as shown in reference image)
              if (t.isGst && design.showTaxSummary)
                pw.Table(
                  border: const pw.TableBorder(
                    bottom: pw.BorderSide(width: 0.6),
                    horizontalInside: pw.BorderSide(width: 0.4),
                    verticalInside: pw.BorderSide(width: 0.4),
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1),
                    1: const pw.FlexColumnWidth(1),
                    2: const pw.FlexColumnWidth(0.8),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(0.8),
                    5: const pw.FlexColumnWidth(1),
                    6: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isModern ? accent : PdfColors.grey100,
                      ),
                      children: [
                        tblCell('HSN/SAC',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('Taxable Value',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('CGST %',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('CGST Amount',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('SGST %',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('SGST Amount',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                        tblCell('Total Tax',
                            bold: true,
                            align: pw.Alignment.center,
                            color: isModern ? PdfColors.white : null),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        tblCell(
                            t.lines.isNotEmpty && t.lines.first.hsn.isNotEmpty
                                ? t.lines.first.hsn
                                : '25171010',
                            align: pw.Alignment.center),
                        tblCell('Rs. ${taxableVal.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                        tblCell('9%', align: pw.Alignment.center),
                        tblCell('Rs. ${t.cgst.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                        tblCell('9%', align: pw.Alignment.center),
                        tblCell('Rs. ${t.sgst.toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                        tblCell('Rs. ${(t.cgst + t.sgst).toStringAsFixed(2)}',
                            align: pw.Alignment.centerRight),
                      ],
                    ),
                  ],
                ),

              // Declaration Box
              if (design.showDeclaration ||
                  design.termsAndConditions.trim().isNotEmpty)
                pw.Container(
                  decoration: const pw.BoxDecoration(
                      border: pw.Border(bottom: pw.BorderSide(width: 0.6))),
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (design.showDeclaration) ...[
                        pw.Text('Declaration',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                color: isModern ? accent : null,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'We declare that this invoice shows the actual price of the goods described and that all particulars are true and correct.',
                          style: const pw.TextStyle(fontSize: 6.5),
                        ),
                      ],
                      if (design.showDeclaration &&
                          design.termsAndConditions.trim().isNotEmpty)
                        pw.SizedBox(height: 4),
                      if (design.termsAndConditions.trim().isNotEmpty) ...[
                        pw.Text('Terms & Conditions',
                            style: pw.TextStyle(
                                fontSize: 7.5,
                                color: isModern ? accent : null,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(design.termsAndConditions.trim(),
                            style: const pw.TextStyle(fontSize: 6.5)),
                      ],
                    ],
                  ),
                ),

              // Bank Details & Signatory Section
              if (design.showBankDetails || design.showSignature)
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (design.showBankDetails)
                      pw.Expanded(
                        flex: 3,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('COMPANY BANK DETAILS',
                                  style: pw.TextStyle(
                                      fontSize: 7.5,
                                      color: isModern ? accent : null,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                  'Bank Name : ${c.bankName.isNotEmpty ? c.bankName : 'ICICI BANK LIMITED'}',
                                  style: const pw.TextStyle(fontSize: 7)),
                              pw.Text(
                                  'A/C No. : ${c.accountNo.isNotEmpty ? c.accountNo : '606605027347'}',
                                  style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(
                                  'Branch & IFSC : ${c.branch.isNotEmpty ? c.branch : 'Kancheepuram'} / ${c.ifsc.isNotEmpty ? c.ifsc : 'ICIC0006066'}',
                                  style: const pw.TextStyle(fontSize: 7)),
                            ],
                          ),
                        ),
                      ),
                    if (design.showBankDetails && design.showSignature)
                      pw.Container(
                          width: 0.6, height: 54, color: PdfColors.black),
                    if (design.showSignature)
                      pw.Expanded(
                        flex: 2,
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text('For ${c.displayName.toUpperCase()}',
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      color: isModern ? accent : null,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 25),
                              pw.Text('Authorised Signatory',
                                  style: pw.TextStyle(
                                      fontSize: 7.5,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),

        pw.SizedBox(height: 5),

        // 3. Bottom Grey Footer Bar
        pw.Container(
          color: isModern ? accent : PdfColors.grey200,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${c.displayName} - Copyright 2026',
                  style: pw.TextStyle(
                      fontSize: 6.5, color: isModern ? PdfColors.white : null)),
              pw.Text(
                  design.footerText.trim().isEmpty
                      ? 'Computer generated document.'
                      : design.footerText.trim(),
                  style: pw.TextStyle(
                      fontSize: 6.5,
                      color: isModern ? PdfColors.white : null,
                      fontStyle: pw.FontStyle.italic)),
            ],
          ),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> buildThermalReceiptPdf(
  Company c,
  BusinessTransaction t,
) async {
  final doc = pw.Document();
  final money = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs.');
  final dateFormat = DateFormat('dd-MM-yyyy hh:mm a');
  pw.MemoryImage? logo;
  if (c.logo != null && c.logo!.isNotEmpty) {
    try {
      logo = pw.MemoryImage(base64Decode(c.logo!.split(',').last));
    } catch (_) {}
  }

  final wrappedLineHeight = t.lines.fold<double>(0, (height, line) {
    final nameRows = (line.name.length / 18).ceil().clamp(1, 4);
    return height + 16 + (nameRows * 8);
  });
  final headerHeight = 72.0 +
      (logo == null ? 0 : 42) +
      (c.address.isEmpty ? 0 : 18) +
      (c.phone.isEmpty ? 0 : 10) +
      (c.gstin.isEmpty ? 0 : 10);
  final contentHeight = headerHeight + wrappedLineHeight + 150.0;
  final format = PdfPageFormat.roll80.copyWith(
    height: contentHeight < 280 ? 280 : contentHeight,
    marginTop: 6,
    marginBottom: 6,
    marginLeft: 8,
    marginRight: 8,
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (ctx) => [
        if (logo != null)
          pw.Center(
            child: pw.Image(
              logo,
              width: 42,
              height: 36,
              fit: pw.BoxFit.contain,
            ),
          ),
        if (logo != null) pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            c.displayName.toUpperCase(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ),
        if (c.address.isNotEmpty)
          pw.Center(
            child: pw.Text(
              c.address,
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (c.phone.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'Ph: ${c.phone}',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        if (c.gstin.isNotEmpty)
          pw.Center(
            child: pw.Text(
              'GSTIN: ${c.gstin}',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ),
        pw.SizedBox(height: 4),
        pw.Text('------------------------------------------------',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Bill No: ${t.number}',
                style:
                    pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            pw.Text(t.paymentMode.toUpperCase(),
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        pw.Text('Date: ${dateFormat.format(t.date)}',
            style: const pw.TextStyle(fontSize: 8)),
        if (t.partyName.isNotEmpty &&
            t.partyName.toLowerCase() != 'walk-in customer')
          pw.Text('Customer: ${t.partyName}',
              style: const pw.TextStyle(fontSize: 8)),
        pw.Text('------------------------------------------------',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Row(
          children: [
            pw.Expanded(
                flex: 5,
                child: pw.Text('Item',
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Qty',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Price',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Total',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                        fontSize: 8, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        pw.Text('------------------------------------------------',
            style: const pw.TextStyle(fontSize: 8)),
        for (final li in t.lines)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(li.name, style: const pw.TextStyle(fontSize: 8)),
                pw.Row(
                  children: [
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text('${li.quantity} ${li.unit}',
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Expanded(
                        flex: 4,
                        child: pw.Text('@ ${li.price.toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Expanded(
                        flex: 5,
                        child: pw.Text(li.total.toStringAsFixed(2),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 8))),
                  ],
                ),
              ],
            ),
          ),
        pw.Text('------------------------------------------------',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Sub Total:', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(money.format(t.subtotal),
                style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
        if (t.discount > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Discount:', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('-${money.format(t.discount)}',
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        if (t.isGst || t.cgst + t.sgst > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GST @ 18% (CGST 9% + SGST 9%):',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Text(money.format(t.cgst + t.sgst),
                  style: const pw.TextStyle(fontSize: 8)),
            ],
          ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('GRAND TOTAL:',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(money.format(t.total),
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        pw.Text('------------------------------------------------',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Center(
          child: pw.Text(
            'Total Items: ${t.lines.length} | Qty: ${t.lines.fold<double>(0, (acc, l) => acc + l.quantity)}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            'Thank you! Visit again.',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );

  return doc.save();
}
