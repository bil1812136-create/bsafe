import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bsafe_app/models/inspection_model.dart';

/// 產生 .docx (Office Open XML) 格式的巡檢報告
class WordExportService {
  /// 匯出 Word 文件，包含專案所有樓層的缺陷與 AI 分析
  static Future<void> exportReport({
    required String outputPath,
    required String buildingName,
    required List<InspectionSession> sessions,
  }) async {
    // 依樓層排序
    final sorted = List<InspectionSession>.from(sessions)
      ..sort((a, b) => a.floor.compareTo(b.floor));

    // 建立 document.xml body 內容
    final body = StringBuffer();

    // 標題
    body.writeln(_heading('B-SAFE Inspection Report', level: 1));
    body.writeln(_paragraph('Project: $buildingName'));
    body.writeln(_paragraph(
        'Export Date: ${DateTime.now().toString().substring(0, 16)}'));
    body.writeln(_paragraph('Floors: ${sorted.length}'));
    body.writeln(_paragraph(''));

    // 收集所有圖片
    final images = <_ImageEntry>[];

    for (final session in sorted) {
      body.writeln(_heading('${session.floor}F', level: 2));
      body.writeln(_paragraph('Inspection Points: ${session.totalPins}'));
      body.writeln(_paragraph(
          'Defect Summary: Low Risk ${session.lowRiskDefects} / '
          'Medium Risk ${session.mediumRiskDefects} / '
          'High Risk ${session.highRiskDefects}'));
      body.writeln(_paragraph(''));

      int defectNum = 0;
      for (int i = 0; i < session.pins.length; i++) {
        final pin = session.pins[i];
        if (pin.defects.isEmpty) continue;

        body.writeln(_heading(
            'Inspection Point #${i + 1}  (${pin.x.toStringAsFixed(2)}, ${pin.y.toStringAsFixed(2)})',
            level: 3));

        for (int j = 0; j < pin.defects.length; j++) {
          defectNum++;
          final defect = pin.defects[j];
          final riskLabel = defect.riskLevelLabel;

          body.writeln(_heading('Defect $defectNum — $riskLabel', level: 4));

          // 風險等級
          body.writeln(_paragraph('Risk Level: $riskLabel'));

          // Structured fields
          if (defect.buildingElement != null && defect.buildingElement!.isNotEmpty) {
            body.writeln(_paragraph('Building Element: ${defect.buildingElement}'));
          }
          if (defect.defectType != null && defect.defectType!.isNotEmpty) {
            body.writeln(_paragraph('Defect Type: ${defect.defectType}'));
          }
          if (defect.diagnosis != null && defect.diagnosis!.isNotEmpty) {
            body.writeln(_paragraph('Diagnosis: ${defect.diagnosis}'));
          }
          if (defect.suspectedCause != null && defect.suspectedCause!.isNotEmpty) {
            body.writeln(_paragraph('Suspected Cause: ${defect.suspectedCause}'));
          }
          if (defect.recommendation != null && defect.recommendation!.isNotEmpty) {
            body.writeln(_paragraph('Inspector Recommendation: ${defect.recommendation}'));
          }
          if (defect.defectSize != null && defect.defectSize!.isNotEmpty) {
            body.writeln(_paragraph('Defect Size: ${defect.defectSize}'));
          }

          // Additional information fields
          if (defect.extentOfDefect != null) {
            body.writeln(_paragraph('Extent of Defect: ${defect.extentOfDefect == 'locally' ? 'Locally noted' : 'Generally noted'}'));
          }
          if (defect.currentUse != null && defect.currentUse!.isNotEmpty) {
            body.writeln(_paragraph('Room Current Use: ${defect.currentUse}'));
          }
          if (defect.designedUse != null && defect.designedUse!.isNotEmpty) {
            body.writeln(_paragraph('Room Designed Use: ${defect.designedUse}'));
          }
          if (defect.onlyTypicalFloor != null) {
            body.writeln(_paragraph('Only Typical Floor: ${defect.onlyTypicalFloor! ? 'Yes' : 'No'}'));
          }
          if (defect.useOfAbove != null && defect.useOfAbove!.isNotEmpty) {
            body.writeln(_paragraph('Use of Above: ${defect.useOfAbove}'));
          }
          if (defect.adjacentWetArea != null) {
            body.writeln(_paragraph('Adjacent Space is Wet Area: ${defect.adjacentWetArea! ? 'Yes' : 'No'}'));
          }
          if (defect.adjacentExternalWall != null) {
            body.writeln(_paragraph('Adjacent to External Wall: ${defect.adjacentExternalWall! ? 'Yes' : 'No'}'));
          }
          if (defect.concealedPipeworks != null) {
            body.writeln(_paragraph('Concealed Pipeworks: ${defect.concealedPipeworks! ? 'Yes' : 'No'}'));
          }
          if (defect.repetitivePattern != null && defect.repetitivePattern!.isNotEmpty) {
            body.writeln(_paragraph('Repetitive Pattern: ${defect.repetitivePattern}'));
          }
          if (defect.heavyLoadingAbove != null) {
            body.writeln(_paragraph('Heavy Loading on Floor Above: ${defect.heavyLoadingAbove! ? 'Yes' : 'No'}'));
          }
          if (defect.remarks != null && defect.remarks!.isNotEmpty) {
            body.writeln(_paragraph('Remarks: ${defect.remarks}'));
          }

          // AI 分析描述
          if (defect.description != null && defect.description!.isNotEmpty) {
            body.writeln(_paragraph('AI Analysis: ${defect.description}'));
          }

          // 建議
          if (defect.recommendations.isNotEmpty) {
            body.writeln(_paragraph('Recommendations:'));
            for (final rec in defect.recommendations) {
              body.writeln(_bulletPoint(rec));
            }
          }

          // AI 對話記錄
          if (defect.chatMessages.isNotEmpty) {
            body.writeln(_paragraph('Chat History:'));
            for (final msg in defect.chatMessages) {
              final prefix = msg.role == 'user' ? 'User' : 'AI';
              body.writeln(_paragraph('[$prefix] ${msg.content}'));
            }
          }

          // 缺陷圖片
          if (defect.imageBase64 != null && defect.imageBase64!.isNotEmpty) {
            final imgId = 'rId${100 + images.length}';
            final imgFileName = 'image${images.length + 1}.jpg';
            images.add(_ImageEntry(
              rId: imgId,
              fileName: imgFileName,
              base64Data: defect.imageBase64!,
            ));
            body.writeln(_imageBlock(imgId));
          }

          body.writeln(_paragraph(''));
        }
      }

      if (defectNum == 0) {
        body.writeln(_paragraph('No defect records for this floor.'));
        body.writeln(_paragraph(''));
      }
    }

    // 組裝 DOCX zip
    final archive = Archive();

    // [Content_Types].xml
    archive.addFile(_textFile('[Content_Types].xml', _contentTypes(images)));

    // _rels/.rels
    archive.addFile(_textFile('_rels/.rels', _rootRels()));

    // word/_rels/document.xml.rels
    archive.addFile(
        _textFile('word/_rels/document.xml.rels', _documentRels(images)));

    // word/document.xml
    archive.addFile(_textFile('word/document.xml', _documentXml(body.toString())));

    // word/styles.xml
    archive.addFile(_textFile('word/styles.xml', _stylesXml()));

    // 圖片檔案
    for (final img in images) {
      final bytes = base64Decode(img.base64Data);
      archive.addFile(ArchiveFile(
        'word/media/${img.fileName}',
        bytes.length,
        bytes,
      ));
    }

    // 寫入檔案
    final encoded = ZipEncoder().encode(archive);
    final file = File(outputPath);
    await file.writeAsBytes(Uint8List.fromList(encoded));
  }

  // ===== XML 建構輔助 =====

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _heading(String text, {int level = 1}) {
    final styleId = 'Heading$level';
    return '''
<w:p>
  <w:pPr><w:pStyle w:val="$styleId"/></w:pPr>
  <w:r><w:t>${_xmlEscape(text)}</w:t></w:r>
</w:p>''';
  }

  static String _paragraph(String text) {
    // 支援多行：每行一個 run，用 w:br 換行
    final lines = text.split('\n');
    final runs = StringBuffer();
    for (int i = 0; i < lines.length; i++) {
      if (i > 0) runs.writeln('<w:r><w:br/></w:r>');
      runs.writeln('<w:r><w:t xml:space="preserve">${_xmlEscape(lines[i])}</w:t></w:r>');
    }
    return '<w:p>$runs</w:p>';
  }

  static String _bulletPoint(String text) {
    return '''
<w:p>
  <w:pPr>
    <w:pStyle w:val="ListBullet"/>
    <w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>
  </w:pPr>
  <w:r><w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r>
</w:p>''';
  }

  static String _imageBlock(String rId) {
    // 圖片寬度約 15cm = 5400000 EMU，高度按比例
    const cx = 5400000;
    const cy = 3600000;
    return '''
<w:p>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$cx" cy="$cy"/>
        <wp:docPr id="1" name="Picture"/>
        <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
              <pic:nvPicPr>
                <pic:cNvPr id="0" name=""/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$rId"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0"/>
                  <a:ext cx="$cx" cy="$cy"/>
                </a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>''';
  }

  // ===== OOXML 結構檔案 =====

  static String _contentTypes(List<_ImageEntry> images) {
    final imgOverrides = StringBuffer();
    for (final img in images) {
      imgOverrides.writeln(
          '  <Override PartName="/word/media/${img.fileName}" ContentType="image/jpeg"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="jpg" ContentType="image/jpeg"/>
  <Default Extension="jpeg" ContentType="image/jpeg"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
$imgOverrides</Types>''';
  }

  static String _rootRels() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';
  }

  static String _documentRels(List<_ImageEntry> images) {
    final rels = StringBuffer();
    rels.writeln(
        '  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>');
    for (final img in images) {
      rels.writeln(
          '  <Relationship Id="${img.rId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${img.fileName}"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
$rels</Relationships>''';
  }

  static String _documentXml(String bodyContent) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
  xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
  xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
  xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
<w:body>
$bodyContent
<w:sectPr>
  <w:pgSz w:w="11906" w:h="16838"/>
  <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>
</w:sectPr>
</w:body>
</w:document>''';
  }

  static String _stylesXml() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:pPr><w:spacing w:before="360" w:after="120"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="48"/><w:color w:val="1F4E79"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:pPr><w:spacing w:before="240" w:after="80"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="36"/><w:color w:val="2E75B6"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:pPr><w:spacing w:before="200" w:after="60"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="404040"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:pPr><w:spacing w:before="160" w:after="40"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="24"/><w:color w:val="595959"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="ListBullet">
    <w:name w:val="List Bullet"/>
    <w:pPr><w:ind w:left="720"/></w:pPr>
  </w:style>
</w:styles>''';
  }

  static ArchiveFile _textFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }
}

class _ImageEntry {
  final String rId;
  final String fileName;
  final String base64Data;

  _ImageEntry({
    required this.rId,
    required this.fileName,
    required this.base64Data,
  });
}
